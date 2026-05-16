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

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.klck.tuner.analysis")
    private var smoothed: Double = 0

    private let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    func toggle() {
        isListening ? stop() : start()
    }

    func start() {
        guard !isListening else { return }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
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
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self,
                  let channel = buffer.floatChannelData?[0] else { return }
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
        } catch {
            NSLog("Klck: tuner failed to start: \(error)")
        }
    }

    private func publish(_ freq: Double?) {
        guard let freq, freq > 0 else {
            hasSignal = false
            return
        }
        hasSignal = true
        // Exponential smoothing to steady the readout.
        smoothed = smoothed == 0 ? freq : smoothed * 0.8 + freq * 0.2
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
        guard n > 1024 else { return nil }

        // Remove DC and measure level.
        var mean: Float = 0
        for s in samples { mean += s }
        mean /= Float(n)

        var rms: Float = 0
        var buf = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let v = samples[i] - mean
            buf[i] = v
            rms += v * v
        }
        rms = (rms / Float(n)).squareRoot()
        guard rms > 0.01 else { return nil }   // too quiet — ignore

        let minFreq = 50.0
        let maxFreq = 1500.0
        let minLag = max(Int(sampleRate / maxFreq), 2)
        let maxLag = min(Int(sampleRate / minFreq), n - 1)
        guard maxLag > minLag else { return nil }

        var bestLag = -1
        var bestValue: Float = 0
        var prev: Float = 0
        var rising = false

        for lag in minLag...maxLag {
            var sum: Float = 0
            for i in 0..<(n - lag) {
                sum += buf[i] * buf[i + lag]
            }
            // Track the first strong local maximum after the ACF starts rising.
            if sum > prev { rising = true }
            if rising && sum < prev && bestLag == -1 {
                bestLag = lag - 1
                bestValue = prev
            }
            if sum > bestValue {
                bestValue = sum
                bestLag = lag
            }
            prev = sum
        }
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
