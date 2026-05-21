import AVFoundation
import os.lock

/// Click timbre.
enum ClickWaveform: Int, Codable, CaseIterable, Identifiable {
    case sine = 0
    case triangle = 1
    case square = 2
    case noise = 3

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .sine:     return "Sine"
        case .triangle: return "Wood"
        case .square:   return "Beep"
        case .noise:    return "Click"
        }
    }
}

/// One subdivision layer as the audio thread sees it.
struct LayerSnapshot {
    var enabled: Bool
    var pulsesPerBeat: Int   // 1 = quarter, 2 = eighth, 3 = triplet, 4 = sixteenth
    var volume: Float        // 0...1
    var frequency: Float     // click pitch in Hz
    var waveform: ClickWaveform = .sine
}

/// Immutable parameter snapshot consumed by the render callback.
struct EngineParams {
    var bpm: Double = 120
    var beatsPerCycle: Int = 4
    /// Per-beat state: 0 = muted, 1 = normal, 2 = accent.
    var accents: [Int] = [2, 1, 1, 1]
    var layers: [LayerSnapshot] = []
    var masterVolume: Float = 0.9
    /// 0 = straight, up to ~0.6 = hard triplet swing (delays off-beat subdivisions).
    var swing: Float = 0
    var accentWaveform: ClickWaveform = .sine
    var beatWaveform: ClickWaveform = .sine
    /// Quiet Count: play `quietPlayBars`, then silence `quietMuteBars`, repeat.
    var quietEnabled: Bool = false
    var quietPlayBars: Int = 4
    var quietMuteBars: Int = 4

    /// When true, the click pattern is shifted by half a beat so audible
    /// hits land on the "and" of each beat instead of on the beat itself.
    /// Beat lights move with the audio so visual + audio stay in sync.
    var clickOnOffbeats: Bool = false

    /// Whether the metronome click is scheduled (engine may run for the tone
    /// generator while this is false).
    var metronomeOn: Bool = false
    /// Bump to restart the beat scheduler from bar 1 on the next render block.
    var transportEpoch: Int = 0

    // Reference tone generator.
    var toneEnabled: Bool = false
    var toneFrequency: Float = 440
    var toneVolume: Float = 0.3
}

/// A single enveloped click voice.
private struct Voice {
    var active = false
    var phase: Float = 0          // 0...2π
    var phaseInc: Float = 0
    var env: Float = 0
    var decay: Float = 0
    var waveform: Int32 = 0
}

/// Sample-accurate metronome audio engine.
///
/// Timing is computed in absolute sample frames inside the `AVAudioSourceNode`
/// render callback, so it is immune to UI / timer jitter. Parameters are handed
/// to the audio thread through a lock-guarded snapshot (lock held only for the
/// duration of a small struct copy).
final class AudioEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleRate: Double = 48_000

    // Parameter handoff (main thread writes, audio thread reads).
    private var paramsLock = os_unfair_lock_s()
    private var params = EngineParams()

    // Metrics handoff (audio thread writes, main thread reads).
    private var metricsLock = os_unfair_lock_s()
    private var _measureIndex: Int = 0
    private var _beatIndex: Int = 0       // 0-based beat within the current measure
    private var _beatTick: Int = 0        // monotonic; bumps on every beat boundary

    // Audio-thread-only scheduler state.
    private var sampleClock: Int64 = 0
    private var mainBeatCounter: Int = 0
    private var nextMainFrame: Double = 0
    private var nextLayerFrame: [Double] = []
    private var layerPulseCounter: [Int] = []
    private var voices = [Voice](repeating: Voice(), count: 24)
    private var rng: UInt32 = 0x9E3779B9
    private var lastEpoch: Int = -1
    private var tonePhase: Float = 0

    private(set) var isRunning = false

    /// Live transport position, read by the practice driver and the beat lights.
    struct Metrics {
        var measure = 0
        var beatIndex = 0
        var beatTick = 0
    }

    var metrics: Metrics {
        os_unfair_lock_lock(&metricsLock)
        let m = Metrics(measure: _measureIndex, beatIndex: _beatIndex, beatTick: _beatTick)
        os_unfair_lock_unlock(&metricsLock)
        return m
    }

    /// Measures elapsed since the last `start()` — read by the practice driver.
    var currentMeasure: Int { metrics.measure }

    // MARK: Parameter updates

    func update(_ newParams: EngineParams) {
        os_unfair_lock_lock(&paramsLock)
        params = newParams
        os_unfair_lock_unlock(&paramsLock)
    }

    private func snapshot() -> EngineParams {
        os_unfair_lock_lock(&paramsLock)
        let p = params
        os_unfair_lock_unlock(&paramsLock)
        return p
    }

    private func publishMeasure(_ m: Int) {
        os_unfair_lock_lock(&metricsLock)
        _measureIndex = m
        os_unfair_lock_unlock(&metricsLock)
    }

    private func publishBeat(measure: Int, beatIndex: Int) {
        os_unfair_lock_lock(&metricsLock)
        _measureIndex = measure
        _beatIndex = beatIndex
        _beatTick &+= 1
        os_unfair_lock_unlock(&metricsLock)
    }

    // MARK: Transport

    /// Ensures the audio hardware is running. The metronome click and the
    /// reference tone are gated by params, so the model calls this whenever
    /// *either* needs output, and `stop()` when neither does.
    func start() {
        guard !isRunning else { return }
        activateSession()
        configureIfNeeded()
        do {
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Klck: audio engine failed to start: \(error)")
        }
    }

    /// iOS requires an active `AVAudioSession`; macOS has none. `.playback`
    /// keeps the click audible with the silent switch on and (paired with the
    /// `audio` background mode) lets practice continue when the screen locks.
    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            NSLog("Klck: audio session activation failed: \(error)")
        }
        #endif
    }

    func stop() {
        guard isRunning else { return }
        engine.pause()
        isRunning = false
    }

    /// Restarts the beat scheduler from bar 1 on the next render block.
    private func resetScheduler(at clock: Double, layerCount: Int, offset: Double = 0) {
        mainBeatCounter = 0
        nextMainFrame = clock + offset
        nextLayerFrame = [Double](repeating: clock + offset, count: layerCount)
        layerPulseCounter = [Int](repeating: 0, count: layerCount)
        for i in voices.indices { voices[i].active = false }
        publishMeasure(0)
    }

    // MARK: Engine graph

    private func configureIfNeeded() {
        guard sourceNode == nil else { return }

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48_000

        let renderFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            self.render(frameCount: Int(frameCount), abl: audioBufferList)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: renderFormat)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: renderFormat)
        sourceNode = node
        engine.prepare()
    }

    // MARK: Render callback (audio thread — no allocations, no locks beyond the snapshot copy)

    private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        let p = snapshot()
        let buffers = UnsafeMutableAudioBufferListPointer(abl)

        let twoPi = Float.pi * 2
        let framesPerBeat = sampleRate * 60.0 / max(p.bpm, 1)
        let beatsPerCycle = max(p.beatsPerCycle, 1)
        let quietCycle = max(p.quietPlayBars + p.quietMuteBars, 1)
        let accentWF = p.accentWaveform.rawValue
        let beatWF = p.beatWaveform.rawValue

        // Lock-free transport (re)start: model bumps the epoch, we reset here.
        // In off-beat mode the first beat fires half a period later so the
        // entire click pattern lands on the "and" of each beat.
        if p.transportEpoch != lastEpoch {
            lastEpoch = p.transportEpoch
            let offset = p.clickOnOffbeats ? framesPerBeat / 2 : 0
            resetScheduler(at: Double(sampleClock), layerCount: p.layers.count, offset: offset)
        }

        // Keep scheduler arrays consistent with the current layer count.
        if nextLayerFrame.count != p.layers.count {
            nextLayerFrame = [Double](repeating: Double(sampleClock), count: p.layers.count)
            layerPulseCounter = [Int](repeating: 0, count: p.layers.count)
        }

        let toneInc = (Float.pi * 2 * max(p.toneFrequency, 1)) / Float(sampleRate)

        for frame in 0..<frameCount {
            let now = Double(sampleClock) + Double(frame)

            let measure = mainBeatCounter / beatsPerCycle
            let muted = p.quietEnabled && (measure % quietCycle) >= p.quietPlayBars

            // --- Main beat scheduler ---
            if p.metronomeOn && now >= nextMainFrame {
                let idx = mainBeatCounter % beatsPerCycle
                let state = idx < p.accents.count ? p.accents[idx] : 1
                if !muted {
                    if state == 2 {
                        trigger(frequency: 2_000, amplitude: 1.0, lengthSec: 0.055, waveform: accentWF)
                    } else if state == 1 {
                        trigger(frequency: 1_000, amplitude: 0.6, lengthSec: 0.045, waveform: beatWF)
                    }
                }
                publishBeat(measure: measure, beatIndex: idx)
                mainBeatCounter += 1
                nextMainFrame += framesPerBeat
            }

            // --- Subdivision layers (with swing on even subdivisions) ---
            for li in p.layers.indices {
                let layer = p.layers[li]
                let pulses = max(layer.pulsesPerBeat, 1)
                let basePulse = framesPerBeat / Double(pulses)
                if p.metronomeOn && now >= nextLayerFrame[li] {
                    if !muted && layer.enabled && layer.volume > 0.0001 {
                        trigger(
                            frequency: layer.frequency,
                            amplitude: layer.volume * 0.5,
                            lengthSec: 0.030,
                            waveform: layer.waveform.rawValue
                        )
                    }
                    // Swing: lengthen the on-pulse, shorten the off-pulse.
                    // Only meaningful for even subdivisions (8th/16th).
                    let parity = layerPulseCounter[li] % 2
                    let swingAmt = (pulses % 2 == 0) ? Double(p.swing) : 0
                    let interval = parity == 0
                        ? basePulse * (1.0 + swingAmt)
                        : basePulse * (1.0 - swingAmt)
                    layerPulseCounter[li] += 1
                    nextLayerFrame[li] += interval
                }
            }

            // --- Mix active voices ---
            var sample: Float = 0
            for vi in voices.indices where voices[vi].active {
                sample += oscillator(voices[vi]) * voices[vi].env
                voices[vi].phase += voices[vi].phaseInc
                if voices[vi].phase > twoPi { voices[vi].phase -= twoPi }
                voices[vi].env *= voices[vi].decay
                if voices[vi].env < 0.0005 { voices[vi].active = false }
            }
            sample *= p.masterVolume

            // --- Reference tone (independent of the metronome) ---
            if p.toneEnabled {
                sample += sinf(tonePhase) * p.toneVolume
                tonePhase += toneInc
                if tonePhase > twoPi { tonePhase -= twoPi }
            }

            if sample > 1 { sample = 1 } else if sample < -1 { sample = -1 }

            for buffer in buffers {
                let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                ptr[frame] = sample
            }
        }

        sampleClock += Int64(frameCount)
    }

    private func oscillator(_ v: Voice) -> Float {
        switch v.waveform {
        case 1: // triangle ("wood")
            let t = v.phase / (Float.pi * 2)
            return (4 * abs(t - 0.5) - 1)
        case 2: // square ("beep")
            return v.phase < Float.pi ? 0.7 : -0.7
        case 3: // filtered noise ("click")
            rng = rng &* 1_664_525 &+ 1_013_904_223
            return (Float(rng >> 8) / Float(1 << 24)) * 2 - 1
        default: // sine
            return sinf(v.phase)
        }
    }

    private func trigger(frequency: Float, amplitude: Float, lengthSec: Float, waveform: Int) {
        // Find a free voice; if none, steal the quietest.
        var slot = -1
        for i in voices.indices where !voices[i].active { slot = i; break }
        if slot == -1 {
            var minEnv: Float = .greatestFiniteMagnitude
            for i in voices.indices where voices[i].env < minEnv {
                minEnv = voices[i].env; slot = i
            }
        }
        guard slot >= 0 else { return }

        let sr = Float(sampleRate)
        let totalSamples = max(lengthSec * sr, 1)
        voices[slot].active = true
        voices[slot].phase = 0
        voices[slot].phaseInc = (Float.pi * 2 * frequency) / sr
        voices[slot].env = amplitude
        voices[slot].waveform = Int32(waveform)
        // Exponential decay reaching ~0.0005 at the end of lengthSec.
        voices[slot].decay = powf(0.0005 / max(amplitude, 0.0005), 1.0 / totalSamples)
    }
}
