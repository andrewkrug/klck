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
    var waveform: ClickWaveform = .sine

    enum CodingKeys: String, CodingKey {
        case id, name, bpm, beatsPerCycle, accents, layers, masterVolume, swing, waveform
    }

    init(name: String, bpm: Double, beatsPerCycle: Int, accents: [Int],
         layers: [SubLayer], masterVolume: Double, swing: Double = 0,
         waveform: ClickWaveform = .sine) {
        self.name = name
        self.bpm = bpm
        self.beatsPerCycle = beatsPerCycle
        self.accents = accents
        self.layers = layers
        self.masterVolume = masterVolume
        self.swing = swing
        self.waveform = waveform
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
        waveform = try c.decodeIfPresent(ClickWaveform.self, forKey: .waveform) ?? .sine
    }
}
