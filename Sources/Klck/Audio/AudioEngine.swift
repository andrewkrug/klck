import AVFoundation
import os.lock

/// One subdivision layer as the audio thread sees it.
struct LayerSnapshot {
    var enabled: Bool
    var pulsesPerBeat: Int   // 1 = quarter, 2 = eighth, 3 = triplet, 4 = sixteenth
    var volume: Float        // 0...1
    var frequency: Float     // click pitch in Hz
}

/// Immutable parameter snapshot consumed by the render callback.
struct EngineParams {
    var bpm: Double = 120
    var beatsPerCycle: Int = 4
    /// Per-beat state: 0 = muted, 1 = normal, 2 = accent.
    var accents: [Int] = [2, 1, 1, 1]
    var layers: [LayerSnapshot] = []
    var masterVolume: Float = 0.9
}

/// A single damped-sinusoid click voice.
private struct Voice {
    var active = false
    var phase: Float = 0
    var phaseInc: Float = 0
    var env: Float = 0
    var decay: Float = 0
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

    // Audio-thread-only scheduler state.
    private var sampleClock: Int64 = 0
    private var mainBeatCounter: Int = 0
    private var nextMainFrame: Double = 0
    private var nextLayerFrame: [Double] = []
    private var voices = [Voice](repeating: Voice(), count: 24)

    private(set) var isRunning = false

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

    // MARK: Transport

    func start() {
        guard !isRunning else { return }
        configureIfNeeded()
        resetSchedulerState()
        do {
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Klck: audio engine failed to start: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.pause()
        isRunning = false
    }

    private func resetSchedulerState() {
        sampleClock = 0
        mainBeatCounter = 0
        nextMainFrame = 0
        let layerCount = snapshot().layers.count
        nextLayerFrame = [Double](repeating: 0, count: layerCount)
        for i in voices.indices { voices[i].active = false }
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
        let sr = Float(sampleRate)
        let framesPerBeat = sampleRate * 60.0 / max(p.bpm, 1)

        // Keep scheduler arrays consistent with the current layer count.
        if nextLayerFrame.count != p.layers.count {
            nextLayerFrame = [Double](repeating: Double(sampleClock), count: p.layers.count)
        }

        for frame in 0..<frameCount {
            let now = Double(sampleClock) + Double(frame)

            // --- Main beat scheduler ---
            if now >= nextMainFrame {
                let beatsPerCycle = max(p.beatsPerCycle, 1)
                let idx = mainBeatCounter % beatsPerCycle
                let state = idx < p.accents.count ? p.accents[idx] : 1
                if state == 2 {
                    trigger(frequency: 2_000, amplitude: 1.0, lengthSec: 0.055)
                } else if state == 1 {
                    trigger(frequency: 1_000, amplitude: 0.6, lengthSec: 0.045)
                }
                mainBeatCounter += 1
                nextMainFrame += framesPerBeat
            }

            // --- Subdivision layers ---
            for li in p.layers.indices {
                let layer = p.layers[li]
                let pulses = max(layer.pulsesPerBeat, 1)
                let framesPerPulse = framesPerBeat / Double(pulses)
                if now >= nextLayerFrame[li] {
                    if layer.enabled && layer.volume > 0.0001 {
                        trigger(
                            frequency: layer.frequency,
                            amplitude: layer.volume * 0.5,
                            lengthSec: 0.030
                        )
                    }
                    nextLayerFrame[li] += framesPerPulse
                }
            }

            // --- Mix active voices ---
            var sample: Float = 0
            for vi in voices.indices where voices[vi].active {
                let s = sinf(voices[vi].phase) * voices[vi].env
                sample += s
                voices[vi].phase += voices[vi].phaseInc
                if voices[vi].phase > twoPi { voices[vi].phase -= twoPi }
                voices[vi].env *= voices[vi].decay
                if voices[vi].env < 0.0005 { voices[vi].active = false }
            }
            sample *= p.masterVolume
            if sample > 1 { sample = 1 } else if sample < -1 { sample = -1 }

            for buffer in buffers {
                let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                ptr[frame] = sample
            }
        }

        _ = sr
        sampleClock += Int64(frameCount)
    }

    private func trigger(frequency: Float, amplitude: Float, lengthSec: Float) {
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
        // Exponential decay reaching ~0.0005 at the end of lengthSec.
        voices[slot].decay = powf(0.0005 / max(amplitude, 0.0005), 1.0 / totalSamples)
    }
}
