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
    // MARK: Published state

    @Published var bpm: Double = 120 { didSet { push() } }
    @Published var beatsPerCycle: Int = 4 { didSet { syncAccents(); push() } }
    @Published var accents: [Int] = [2, 1, 1, 1] { didSet { push() } }
    @Published var layers: [SubLayer] = SubLayer.defaults { didSet { push() } }
    @Published var masterVolume: Double = 0.9 { didSet { push() } }
    @Published private(set) var isRunning = false
    @Published private(set) var presets: [Preset] = []

    let minBPM: Double = 30
    let maxBPM: Double = 300

    // MARK: Private

    private let engine = AudioEngine()
    private var tapTimes: [Date] = []

    init() {
        loadPresets()
        push()
    }

    // MARK: Transport

    func toggle() {
        if isRunning {
            engine.stop()
        } else {
            push()
            engine.start()
        }
        isRunning = engine.isRunning
    }

    func setBPM(_ value: Double) {
        bpm = min(max(value.rounded(), minBPM), maxBPM)
    }

    // MARK: Tap tempo

    func tap() {
        let now = Date()
        tapTimes.append(now)
        // Drop taps older than 2s — a new tempo intention.
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
            masterVolume: masterVolume
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
            masterVolume: Float(masterVolume)
        )
        engine.update(snapshot)
    }
}
