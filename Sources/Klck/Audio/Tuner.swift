import AVFoundation
import Combine

/// Chromatic instrument tuner: captures the microphone and estimates the
/// fundamental pitch with autocorrelation, reporting the nearest note and
/// the cents deviation.
@MainActor
final class Tuner: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var hasSignal = false
    @Published private(set) var frequency: Double = 0
    @Published private(set) var noteName: String = "—"
    @Published private(set) var cents: Double = 0          // -50 ... +50
    @Published private(set) var permissionDenied = false
    /// Surfaces audio-pipeline failures to the UI. Cleared on every successful
    /// `start()`. Visible in the tuner panel so a broken session doesn't look
    /// indistinguishable from "no input detected yet".
    @Published private(set) var lastError: String?

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.klck.tuner.analysis")
    private var smoothed: Double = 0

    private let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    func toggle() {
        isListening ? stop() : start()
    }

    func start() {
        guard !isListening else { return }
        lastError = nil
        requestMicrophonePermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.permissionDenied = false
                    self.beginCapture()
                } else {
                    self.permissionDenied = true
                }
            }
        }
    }

    /// iOS 17+ deprecated `AVCaptureDevice.requestAccess(for: .audio)` for
    /// AVAudioSession-based recording in favor of `AVAudioApplication`. Use
    /// the new API where available; fall back for older OS versions.
    private func requestMicrophonePermission(_ completion: @escaping @Sendable (Bool) -> Void) {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: completion)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        }
        #else
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
        #endif
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        hasSignal = false
        noteName = "—"
        frequency = 0
        cents = 0
        smoothed = 0
    }

    private func beginCapture() {
        #if os(iOS)
        // The shared session must be in a recording-capable category before
        // the input node yields a valid format. `.default` mode (not
        // `.measurement`) keeps the standard input path on iPad's mic array,
        // and we drop `.mixWithOthers` so the engine reliably grabs the
        // input route.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                     options: [.defaultToSpeaker,
                                               .allowBluetooth,
                                               .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            lastError = "Audio session: \(error.localizedDescription)"
            NSLog("Klck: tuner audio session failed: \(error)")
            return
        }
        #endif

        // Reset the engine so a previous failed attempt doesn't poison the
        // input node (taps installed on a stale node never deliver buffers).
        if engine.isRunning { engine.stop() }
        engine.reset()

        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)

        // Pick a format the input bus will actually deliver: prefer the
        // hardware format (matches the mic's native rate / channel count),
        // and fall back to mono float-32 @ 48k if the bus still hasn't
        // resolved one. AVAudioEngine refuses to install a tap with a
        // format whose sampleRate is 0.
        let tapFormat: AVAudioFormat = {
            if hwFormat.sampleRate > 0 { return hwFormat }
            return AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 48_000,
                                  channels: 1,
                                  interleaved: false)!
        }()

        // Buffer-size derivation (Nyquist + practical resolution):
        //
        // - The audio sample rate (hardware-default 48 kHz) only has to
        //   satisfy Nyquist for the highest frequency we *detect* (1.5 kHz):
        //   48000 ≥ 2·1500 holds 16×-over by default, so Nyquist isn't the
        //   bottleneck for audio quality here.
        // - The real lever for "real-time feedback" is the analysis window.
        //   With buffer=4096 at 48 kHz we got ~12 pitch updates/sec (~85 ms
        //   latency); buffer=2048 doubles that to ~23 updates/sec (~43 ms).
        // - Lower bound on buffer: the autocorrelator needs ~3 periods of
        //   the lowest target frequency to lock reliably. Low E (82 Hz) has
        //   a 580-sample period at 48 kHz → ~1750 samples minimum. 2048
        //   clears that with margin.
        input.installTap(onBus: 0, bufferSize: 2048, format: tapFormat) { [weak self] buffer, _ in
            guard let self,
                  let channel = buffer.floatChannelData?[0] else { return }
            let sampleRate = buffer.format.sampleRate
            guard sampleRate > 0 else { return }
            let count = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            self.analysisQueue.async {
                let result = Self.detectPitch(samples: samples, sampleRate: sampleRate)
                Task { @MainActor in self.publish(result) }
            }
        }

        do {
            try engine.start()
            isListening = true
            lastError = nil
        } catch {
            lastError = "Audio engine: \(error.localizedDescription)"
            NSLog("Klck: tuner failed to start: \(error)")
            input.removeTap(onBus: 0)
        }
    }

    private func publish(_ freq: Double?) {
        guard let freq, freq > 0 else {
            hasSignal = false
            return
        }
        hasSignal = true
        // Exponential smoothing — with ~23 updates/sec from the new tap
        // window, a 0.7/0.3 mix gives the readout a ~5-frame (~220 ms) time
        // constant: stable when held, but quick enough to track real pitch
        // changes as you bend a string.
        smoothed = smoothed == 0 ? freq : smoothed * 0.7 + freq * 0.3
        frequency = smoothed

        let midi = 69 + 12 * log2(smoothed / 440)
        let nearest = midi.rounded()
        let n = ((Int(nearest) % 12) + 12) % 12
        noteName = "\(noteNames[n])\(Int(nearest) / 12 - 1)"
        cents = (midi - nearest) * 100
    }

    // MARK: Pitch detection (autocorrelation + parabolic interpolation)

    nonisolated static func detectPitch(samples: [Float], sampleRate: Double) -> Double? {
        let n = samples.count
        // Lower bound matches the tap's 2048-sample window — keeps the
        // detector honest about how many full periods of the lowest target
        // frequency it has to work with.
        guard n > 1500 else { return nil }

        // Remove DC and measure level.
        var mean: Float = 0
        for s in samples { mean += s }
        mean /= Float(n)

        var energy: Float = 0    // ACF at lag 0 — used as a peak threshold.
        var buf = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let v = samples[i] - mean
            buf[i] = v
            energy += v * v
        }
        let rms = (energy / Float(n)).squareRoot()
        guard rms > 0.01 else { return nil }   // too quiet — ignore

        let minFreq = 50.0
        let maxFreq = 1500.0
        let minLag = max(Int(sampleRate / maxFreq), 2)
        let maxLag = min(Int(sampleRate / minFreq), n - 1)
        guard maxLag > minLag else { return nil }

        // Take the FIRST significant local maximum of the autocorrelation
        // function. Picking the global maximum is the classic octave-down
        // bug — for periodic input the ACF peaks at every multiple of the
        // fundamental period, and a later (lower-frequency) peak can edge
        // out the true first peak due to windowing or strong even
        // harmonics. The first peak is always the fundamental.
        //
        // Subtlety: we start scanning at `minLag`, but the lag-0 lobe of
        // the ACF can still be near full magnitude there (especially for
        // bass notes), so a naïve "first descent from rising" would
        // misread that lobe as a peak and report a frequency near
        // sampleRate/minLag — i.e. wildly sharp. Require the ACF to dip
        // below `dipThreshold` first, which guarantees we're past the
        // lag-0 envelope before we start trusting peaks.
        let peakThreshold = energy * 0.4
        let dipThreshold = peakThreshold * 0.2

        var firstPeakLag = -1
        var prev: Float = 0
        var rising = false
        var dipped = false

        for lag in minLag...maxLag {
            var sum: Float = 0
            for i in 0..<(n - lag) {
                sum += buf[i] * buf[i + lag]
            }

            if !dipped {
                if sum < dipThreshold { dipped = true }
                prev = sum
                continue
            }

            if sum > prev {
                rising = true
            } else if rising {
                // We just descended past a peak that sat at lag - 1.
                if prev >= peakThreshold {
                    firstPeakLag = lag - 1
                    break
                }
                // Not significant enough; keep scanning for the next peak.
                rising = false
            }
            prev = sum
        }
        let bestLag = firstPeakLag
        guard bestLag > 0 else { return nil }

        // Parabolic interpolation around the peak for sub-sample accuracy.
        let lag = bestLag
        var refined = Double(lag)
        if lag > minLag, lag < maxLag {
            let y0 = acf(buf, lag - 1, n)
            let y1 = acf(buf, lag, n)
            let y2 = acf(buf, lag + 1, n)
            let denom = (y0 - 2 * y1 + y2)
            if abs(denom) > 1e-9 {
                refined = Double(lag) + Double((y0 - y2) / (2 * denom))
            }
        }
        guard refined > 0 else { return nil }
        return sampleRate / refined
    }

    private nonisolated static func acf(_ buf: [Float], _ lag: Int, _ n: Int) -> Float {
        guard lag >= 0, lag < n else { return 0 }
        var sum: Float = 0
        for i in 0..<(n - lag) { sum += buf[i] * buf[i + lag] }
        return sum
    }
}
