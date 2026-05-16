import Foundation
import Combine

/// Per-beat accent state.
enum BeatAccent: Int {
    case muted = 0
    case normal = 1
    case accent = 2

    var next: BeatAccent {
        switch self {
        case .accent: return .normal
        case .normal: return .muted
        case .muted:  return .accent
        }
    }
}

@MainActor
final class MetronomeModel: ObservableObject {
    // MARK: Core state

    @Published var bpm: Double = 120 { didSet { push() } }
    @Published var beatsPerCycle: Int = 4 { didSet { syncAccents(); push() } }
    @Published var accents: [Int] = [2, 1, 1, 1] { didSet { push() } }
    @Published var layers: [SubLayer] = SubLayer.defaults { didSet { push() } }
    @Published var masterVolume: Double = 0.9 { didSet { push() } }

    // MARK: Practice / feel

    @Published var swing: Double = 0 { didSet { push() } }
    @Published var clickSound: ClickWaveform = .sine { didSet { push() } }

    @Published var quietEnabled: Bool = false { didSet { push() } }
    @Published var quietPlayBars: Int = 4 { didSet { push() } }
    @Published var quietMuteBars: Int = 2 { didSet { push() } }

    @Published var rampEnabled: Bool = false
    @Published var rampStartBPM: Double = 80
    @Published var rampTargetBPM: Double = 160
    @Published var rampStepBPM: Double = 4
    @Published var rampEveryBars: Int = 4

    @Published var timerEnabled: Bool = false
    @Published var timerMinutes: Int = 10
    @Published private(set) var timerRemaining: TimeInterval = 0

    @Published private(set) var isRunning = false
    @Published private(set) var presets: [Preset] = []

    /// Live transport position for the beat lights (-1 = stopped).
    @Published private(set) var activeBeat: Int = -1
    /// Bumps on every beat — views observe this to flash in time.
    @Published private(set) var beatPulse: Int = 0

    let minBPM: Double = 30
    let maxBPM: Double = 300

    // MARK: Private

    private let engine = AudioEngine()
    private var tapTimes: [Date] = []
    private var driver: Timer?
    private var lastRampMeasure = 0
    private var lastBeatTick = -1
    private var timerEndDate: Date?

    init() {
        loadPresets()
        push()
    }

    // MARK: Transport

    func toggle() {
        if isRunning {
            stopRunning()
        } else {
            startRunning()
        }
    }

    private func startRunning() {
        if rampEnabled {
            bpm = clampedBPM(rampStartBPM)
        }
        lastRampMeasure = 0
        if timerEnabled {
            timerEndDate = Date().addingTimeInterval(Double(timerMinutes) * 60)
            timerRemaining = Double(timerMinutes) * 60
        }
        lastBeatTick = -1
        activeBeat = -1
        push()
        engine.start()
        isRunning = engine.isRunning
        if isRunning { startDriver() }
    }

    private func stopRunning() {
        engine.stop()
        isRunning = engine.isRunning
        stopDriver()
        timerEndDate = nil
        activeBeat = -1
    }

    func setBPM(_ value: Double) {
        bpm = clampedBPM(value.rounded())
    }

    private func clampedBPM(_ v: Double) -> Double {
        min(max(v, minBPM), maxBPM)
    }

    // MARK: Practice driver (tempo ramp + practice timer)

    private func startDriver() {
        stopDriver()
        let t = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.driverTick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        driver = t
    }

    private func stopDriver() {
        driver?.invalidate()
        driver = nil
    }

    private func driverTick() {
        guard isRunning else { return }

        let m = engine.metrics

        // Beat lights: flash whenever the engine crosses a new beat.
        if m.beatTick != lastBeatTick {
            lastBeatTick = m.beatTick
            activeBeat = m.beatIndex
            beatPulse &+= 1
        }

        // Tempo ramp / stepping, advanced by elapsed measures.
        if rampEnabled, rampEveryBars > 0 {
            let measure = m.measure
            if measure - lastRampMeasure >= rampEveryBars {
                lastRampMeasure = measure
                let goingUp = rampTargetBPM >= rampStartBPM
                let next = goingUp ? bpm + rampStepBPM : bpm - rampStepBPM
                let reached = goingUp ? next >= rampTargetBPM : next <= rampTargetBPM
                bpm = clampedBPM(reached ? rampTargetBPM : next)
            }
        }

        // Practice timer countdown.
        if timerEnabled, let end = timerEndDate {
            timerRemaining = max(0, end.timeIntervalSinceNow)
            if timerRemaining <= 0 {
                stopRunning()
            }
        }
    }

    // MARK: Tap tempo

    func tap() {
        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 2.0 }
        guard tapTimes.count >= 2 else { return }
        var intervals: [Double] = []
        for i in 1..<tapTimes.count {
            intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i - 1]))
        }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return }
        setBPM(60.0 / avg)
    }

    // MARK: Beat / accent editing

    func cycleAccent(_ index: Int) {
        guard index < accents.count else { return }
        let current = BeatAccent(rawValue: accents[index]) ?? .normal
        accents[index] = current.next.rawValue
    }

    private func syncAccents() {
        if accents.count < beatsPerCycle {
            accents.append(contentsOf: Array(repeating: 1, count: beatsPerCycle - accents.count))
        } else if accents.count > beatsPerCycle {
            accents = Array(accents.prefix(beatsPerCycle))
        }
        if accents.first == 0 { accents[0] = 2 }
    }

    // MARK: Presets

    func savePreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = Preset(
            name: trimmed,
            bpm: bpm,
            beatsPerCycle: beatsPerCycle,
            accents: accents,
            layers: layers,
            masterVolume: masterVolume,
            swing: swing,
            waveform: clickSound
        )
        if let idx = presets.firstIndex(where: { $0.name == trimmed }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persistPresets()
    }

    func apply(_ preset: Preset) {
        bpm = preset.bpm
        beatsPerCycle = preset.beatsPerCycle
        accents = preset.accents
        layers = preset.layers
        masterVolume = preset.masterVolume
        swing = preset.swing
        clickSound = preset.waveform
        push()
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    // MARK: Persistence

    private var presetsURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Klck", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("presets.json")
    }

    private func loadPresets() {
        guard let data = try? Data(contentsOf: presetsURL) else { return }
        if let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        }
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: presetsURL, options: .atomic)
    }

    // MARK: Engine sync

    private func push() {
        let snapshot = EngineParams(
            bpm: bpm,
            beatsPerCycle: beatsPerCycle,
            accents: accents,
            layers: layers.map {
                LayerSnapshot(
                    enabled: $0.enabled,
                    pulsesPerBeat: $0.pulsesPerBeat,
                    volume: Float($0.volume),
                    frequency: Float($0.frequency)
                )
            },
            masterVolume: Float(masterVolume),
            swing: Float(swing),
            waveform: clickSound,
            quietEnabled: quietEnabled,
            quietPlayBars: quietPlayBars,
            quietMuteBars: quietMuteBars
        )
        engine.update(snapshot)
    }
}
