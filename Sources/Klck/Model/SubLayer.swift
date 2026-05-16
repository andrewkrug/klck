import Foundation

/// A user-facing subdivision layer (8th notes, triplets, etc.).
struct SubLayer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var pulsesPerBeat: Int
    var volume: Double      // 0...1
    var enabled: Bool
    var frequency: Double   // click pitch in Hz
    var waveform: ClickWaveform = .sine

    init(name: String, pulsesPerBeat: Int, volume: Double, enabled: Bool,
         frequency: Double, waveform: ClickWaveform = .sine) {
        self.name = name
        self.pulsesPerBeat = pulsesPerBeat
        self.volume = volume
        self.enabled = enabled
        self.frequency = frequency
        self.waveform = waveform
    }

    enum CodingKeys: String, CodingKey {
        case id, name, pulsesPerBeat, volume, enabled, frequency, waveform
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        pulsesPerBeat = try c.decode(Int.self, forKey: .pulsesPerBeat)
        volume = try c.decode(Double.self, forKey: .volume)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        frequency = try c.decode(Double.self, forKey: .frequency)
        waveform = try c.decodeIfPresent(ClickWaveform.self, forKey: .waveform) ?? .sine
    }

    static var defaults: [SubLayer] {
        [
            SubLayer(name: "Eighths",   pulsesPerBeat: 2, volume: 0.5, enabled: false, frequency: 1_400, waveform: .sine),
            SubLayer(name: "Triplets",  pulsesPerBeat: 3, volume: 0.5, enabled: false, frequency: 1_600, waveform: .sine),
            SubLayer(name: "Sixteenths", pulsesPerBeat: 4, volume: 0.45, enabled: false, frequency: 1_800, waveform: .triangle),
            SubLayer(name: "Quarters",  pulsesPerBeat: 1, volume: 0.5, enabled: false, frequency: 1_200, waveform: .sine)
        ]
    }
}
