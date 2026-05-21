import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

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
    @Published var beatsPerCycle: Int = 4 {
        didSet {
            syncAccents()
            resizeSubdivisionGrid()
            push()
        }
    }
    @Published var accents: [Int] = [2, 1, 1, 1] { didSet { push() } }
    /// Step-sequencer grid over the bar: 4 cells per beat (the 16th-note
    /// positions). Position 0 of each beat is driven by the existing
    /// `accents` array, so this grid only matters at positions 1, 2, 3.
    /// Re-sized to match `beatsPerCycle * 4` whenever the meter changes.
    @Published var subdivisionGrid: [Bool] = Array(repeating: false, count: 16) {
        didSet { push() }
    }
    /// Triplet sibling of `subdivisionGrid` — 3 cells per beat (the eighth-
    /// note triplet positions). Independent from the 16th grid so a user
    /// can layer 16ths + triplets for polyrhythmic practice. Position 0 of
    /// each beat is the downbeat (silent here; the main beat owns it).
    @Published var tripletGrid: [Bool] = Array(repeating: false, count: 12) {
        didSet { push() }
    }
    /// Legacy multi-layer subdivision mixer. Still part of the model so old
    /// presets continue to decode, but the UI no longer surfaces it; the
    /// audio engine ignores it in favor of `subdivisionGrid`.
    @Published var layers: [SubLayer] = SubLayer.defaults { didSet { push() } }
    @Published var masterVolume: Double = 0.9 { didSet { push() } }

    // MARK: Practice / feel

    @Published var swing: Double = 0 { didSet { push() } }
    @Published var accentSound: ClickWaveform = .sine { didSet { push() } }
    @Published var beatSound: ClickWaveform = .sine { didSet { push() } }
    /// Waveform used for cells in the 16th-note subdivision grid row.
    @Published var subdivisionSound: ClickWaveform = .triangle { didSet { push() } }
    /// Waveform used for cells in the triplet subdivision grid row.
    @Published var tripletSound: ClickWaveform = .triangle { didSet { push() } }
    /// When true, the metronome clicks on the "and" between each beat
    /// instead of on the beat itself — a common practice technique. Toggling
    /// while playing restarts the bar so the offset takes effect immediately.
    @Published var clickOnOffbeats: Bool = false {
        didSet {
            if isRunning { transportEpoch += 1 }
            push()
        }
    }

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

    /// Flash the screen in time with the beat (brighter on the downbeat).
    /// Off by default — opt in via the FLASH button or Feel & Practice.
    @Published var flashEnabled: Bool = false

    // MARK: Reference tone generator

    @Published var toneEnabled: Bool = false { didSet { syncAudio() } }
    @Published var toneFrequency: Double = 440 { didSet { push() } }
    @Published var toneVolume: Double = 0.3 { didSet { push() } }

    @Published private(set) var isRunning = false
    @Published private(set) var presets: [Preset] = []

    // MARK: Setlists

    @Published private(set) var setlists: [Setlist] = []
    @Published private(set) var activeSetlistID: UUID?
    @Published private(set) var activeIndex: Int = 0

    private var itemStartMeasure = 0

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
    private var transportEpoch = 0

    /// MIDI note name for a frequency, e.g. 440 → "A4".
    static func noteName(for frequency: Double) -> String {
        guard frequency > 0 else { return "—" }
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let midi = Int((69 + 12 * log2(frequency / 440)).rounded())
        let n = ((midi % 12) + 12) % 12
        return "\(names[n])\(midi / 12 - 1)"
    }

    init() {
        loadPresets()
        loadSetlists()
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
        transportEpoch += 1   // tells the engine to restart from bar 1
        itemStartMeasure = 0
        isRunning = true
        setIdleTimerDisabled(true)
        syncAudio()
        startDriver()
    }

    private func stopRunning() {
        isRunning = false
        setIdleTimerDisabled(false)
        stopDriver()
        timerEndDate = nil
        activeBeat = -1
        syncAudio()
    }

    /// Keep the screen lit while practicing so the LCD/beat lights stay
    /// visible. No-op on macOS, which never auto-dims a running app's window.
    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    /// Runs the audio hardware whenever the metronome *or* the tone needs it.
    private func syncAudio() {
        if isRunning || toneEnabled {
            engine.start()
        } else {
            engine.stop()
        }
        push()
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

        // Setlist auto-advance after a configured number of bars.
        if let set = activeSetlist,
           activeIndex < set.items.count {
            let bars = set.items[activeIndex].advanceAfterBars
            if bars > 0, m.measure - itemStartMeasure >= bars,
               activeIndex < set.items.count - 1 {
                setlistGo(to: activeIndex + 1)
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

    /// Match both subdivision grids to the current meter. Preserves existing
    /// values when growing (new beats get all-off), truncates when shrinking.
    private func resizeSubdivisionGrid() {
        let target16 = beatsPerCycle * 4
        if subdivisionGrid.count < target16 {
            subdivisionGrid.append(contentsOf: Array(repeating: false, count: target16 - subdivisionGrid.count))
        } else if subdivisionGrid.count > target16 {
            subdivisionGrid = Array(subdivisionGrid.prefix(target16))
        }
        let target3 = beatsPerCycle * 3
        if tripletGrid.count < target3 {
            tripletGrid.append(contentsOf: Array(repeating: false, count: target3 - tripletGrid.count))
        } else if tripletGrid.count > target3 {
            tripletGrid = Array(tripletGrid.prefix(target3))
        }
    }

    func toggleSubdivisionCell(_ index: Int) {
        guard subdivisionGrid.indices.contains(index) else { return }
        subdivisionGrid[index].toggle()
    }

    func toggleTripletCell(_ index: Int) {
        guard tripletGrid.indices.contains(index) else { return }
        tripletGrid[index].toggle()
    }

    /// One-tap presets for the subdivision grid. "Off-beats" lights up only
    /// the "and" cell of each beat (position 2 of the 16th grid). "All 16ths"
    /// fills every off-cell of the 16th row. "All triplets" fills both
    /// non-downbeat triplet cells. "Clear" wipes everything.
    func subdivisionApplyAllEighths() {
        clearAllSubdivisionCells()
        for beat in 0..<beatsPerCycle {
            let i = beat * 4 + 2
            if subdivisionGrid.indices.contains(i) { subdivisionGrid[i] = true }
        }
    }

    func subdivisionApplyAllSixteenths() {
        clearAllSubdivisionCells()
        for i in subdivisionGrid.indices where (i % 4) != 0 {
            subdivisionGrid[i] = true
        }
    }

    func subdivisionApplyAllTriplets() {
        clearAllSubdivisionCells()
        for i in tripletGrid.indices where (i % 3) != 0 {
            tripletGrid[i] = true
        }
    }

    func subdivisionClearAll() {
        clearAllSubdivisionCells()
    }

    private func clearAllSubdivisionCells() {
        subdivisionGrid = Array(repeating: false, count: subdivisionGrid.count)
        tripletGrid = Array(repeating: false, count: tripletGrid.count)
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
            accentWaveform: accentSound,
            beatWaveform: beatSound
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
        accentSound = preset.accentWaveform
        beatSound = preset.beatWaveform
        push()
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        // Drop any setlist stops that referenced it.
        for i in setlists.indices {
            setlists[i].items.removeAll { $0.presetID == preset.id }
        }
        clampActiveIndex()
        persistPresets()
        persistSetlists()
    }

    func preset(for id: UUID) -> Preset? {
        presets.first { $0.id == id }
    }

    // MARK: Setlists

    var activeSetlist: Setlist? {
        guard let id = activeSetlistID else { return nil }
        return setlists.first { $0.id == id }
    }

    func createSetlist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let set = Setlist(name: trimmed)
        setlists.append(set)
        activeSetlistID = set.id
        activeIndex = 0
        persistSetlists()
    }

    func deleteSetlist(_ set: Setlist) {
        setlists.removeAll { $0.id == set.id }
        if activeSetlistID == set.id { activeSetlistID = nil; activeIndex = 0 }
        persistSetlists()
    }

    func activateSetlist(_ set: Setlist) {
        activeSetlistID = set.id
        setlistGo(to: 0)
    }

    func deactivateSetlist() {
        activeSetlistID = nil
        activeIndex = 0
    }

    func addToActiveSetlist(_ preset: Preset) {
        guard let id = activeSetlistID,
              let idx = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[idx].items.append(SetlistItem(presetID: preset.id))
        persistSetlists()
    }

    func removeSetlistItem(at offsets: IndexSet) {
        guard let id = activeSetlistID,
              let idx = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[idx].items.remove(atOffsets: offsets)
        clampActiveIndex()
        persistSetlists()
    }

    func moveSetlistItem(from source: IndexSet, to destination: Int) {
        guard let id = activeSetlistID,
              let idx = setlists.firstIndex(where: { $0.id == id }) else { return }
        setlists[idx].items.move(fromOffsets: source, toOffset: destination)
        persistSetlists()
    }

    func setAdvanceBars(_ bars: Int, forItemAt index: Int) {
        guard let id = activeSetlistID,
              let idx = setlists.firstIndex(where: { $0.id == id }),
              index < setlists[idx].items.count else { return }
        setlists[idx].items[index].advanceAfterBars = max(0, bars)
        persistSetlists()
    }

    var canSetlistNext: Bool {
        guard let s = activeSetlist else { return false }
        return activeIndex < s.items.count - 1
    }

    var canSetlistPrev: Bool {
        activeSetlist != nil && activeIndex > 0
    }

    func setlistNext() { if canSetlistNext { setlistGo(to: activeIndex + 1) } }
    func setlistPrev() { if canSetlistPrev { setlistGo(to: activeIndex - 1) } }

    /// Jumps to a setlist position and applies its preset.
    func setlistGo(to index: Int) {
        guard let set = activeSetlist,
              index >= 0, index < set.items.count else { return }
        activeIndex = index
        itemStartMeasure = engine.metrics.measure
        if let p = preset(for: set.items[index].presetID) {
            apply(p)
        }
    }

    private func clampActiveIndex() {
        let count = activeSetlist?.items.count ?? 0
        if activeIndex >= count { activeIndex = max(0, count - 1) }
    }

    /// Short status line for the LCD, e.g. "GIG 2/5".
    var setlistStatus: String? {
        guard let s = activeSetlist, !s.items.isEmpty else { return nil }
        return "\(s.name.uppercased().prefix(6)) \(activeIndex + 1)/\(s.items.count)"
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

    private var setlistsURL: URL {
        presetsURL.deletingLastPathComponent().appendingPathComponent("setlists.json")
    }

    private func loadSetlists() {
        guard let data = try? Data(contentsOf: setlistsURL) else { return }
        if let decoded = try? JSONDecoder().decode([Setlist].self, from: data) {
            setlists = decoded
        }
    }

    private func persistSetlists() {
        guard let data = try? JSONEncoder().encode(setlists) else { return }
        try? data.write(to: setlistsURL, options: .atomic)
    }

    // MARK: Engine sync

    private func push() {
        // Build the snapshot via piecewise assignment — a single 20+ argument
        // initializer call sometimes pushes Swift's type checker past its
        // expression-complexity budget on a debug build.
        var snapshot = EngineParams()
        snapshot.bpm = bpm
        snapshot.beatsPerCycle = beatsPerCycle
        snapshot.accents = accents
        snapshot.layers = layers.map { layer in
            LayerSnapshot(
                enabled: layer.enabled,
                pulsesPerBeat: layer.pulsesPerBeat,
                volume: Float(layer.volume),
                frequency: Float(layer.frequency),
                waveform: layer.waveform
            )
        }
        snapshot.masterVolume = Float(masterVolume)
        snapshot.swing = Float(swing)
        snapshot.accentWaveform = accentSound
        snapshot.beatWaveform = beatSound
        snapshot.quietEnabled = quietEnabled
        snapshot.quietPlayBars = quietPlayBars
        snapshot.quietMuteBars = quietMuteBars
        snapshot.clickOnOffbeats = clickOnOffbeats
        snapshot.subdivisionGrid = subdivisionGrid
        snapshot.tripletGrid = tripletGrid
        snapshot.subdivisionWaveform = subdivisionSound
        snapshot.tripletWaveform = tripletSound
        snapshot.metronomeOn = isRunning
        snapshot.transportEpoch = transportEpoch
        snapshot.toneEnabled = toneEnabled
        snapshot.toneFrequency = Float(toneFrequency)
        snapshot.toneVolume = Float(toneVolume)
        engine.update(snapshot)
    }
}
