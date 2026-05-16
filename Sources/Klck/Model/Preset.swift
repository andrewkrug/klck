import Foundation

/// A fully recallable metronome configuration.
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var bpm: Double
    var beatsPerCycle: Int
    var accents: [Int]
    var layers: [SubLayer]
    var masterVolume: Double
    var swing: Double = 0
    var accentWaveform: ClickWaveform = .sine
    var beatWaveform: ClickWaveform = .sine

    enum CodingKeys: String, CodingKey {
        case id, name, bpm, beatsPerCycle, accents, layers, masterVolume, swing
        case accentWaveform, beatWaveform
        case waveform   // legacy single-sound key
    }

    init(name: String, bpm: Double, beatsPerCycle: Int, accents: [Int],
         layers: [SubLayer], masterVolume: Double, swing: Double = 0,
         accentWaveform: ClickWaveform = .sine, beatWaveform: ClickWaveform = .sine) {
        self.name = name
        self.bpm = bpm
        self.beatsPerCycle = beatsPerCycle
        self.accents = accents
        self.layers = layers
        self.masterVolume = masterVolume
        self.swing = swing
        self.accentWaveform = accentWaveform
        self.beatWaveform = beatWaveform
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        bpm = try c.decode(Double.self, forKey: .bpm)
        beatsPerCycle = try c.decode(Int.self, forKey: .beatsPerCycle)
        accents = try c.decode([Int].self, forKey: .accents)
        layers = try c.decode([SubLayer].self, forKey: .layers)
        masterVolume = try c.decode(Double.self, forKey: .masterVolume)
        swing = try c.decodeIfPresent(Double.self, forKey: .swing) ?? 0
        // Migrate: an old preset's single `waveform` seeds both roles.
        let legacy = try c.decodeIfPresent(ClickWaveform.self, forKey: .waveform)
        accentWaveform = try c.decodeIfPresent(ClickWaveform.self, forKey: .accentWaveform) ?? legacy ?? .sine
        beatWaveform = try c.decodeIfPresent(ClickWaveform.self, forKey: .beatWaveform) ?? legacy ?? .sine
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(bpm, forKey: .bpm)
        try c.encode(beatsPerCycle, forKey: .beatsPerCycle)
        try c.encode(accents, forKey: .accents)
        try c.encode(layers, forKey: .layers)
        try c.encode(masterVolume, forKey: .masterVolume)
        try c.encode(swing, forKey: .swing)
        try c.encode(accentWaveform, forKey: .accentWaveform)
        try c.encode(beatWaveform, forKey: .beatWaveform)
    }
}
