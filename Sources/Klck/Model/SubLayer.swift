import Foundation

/// A user-facing subdivision layer (8th notes, triplets, etc.).
struct SubLayer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var pulsesPerBeat: Int
    var volume: Double      // 0...1
    var enabled: Bool
    var frequency: Double   // click pitch in Hz

    static var defaults: [SubLayer] {
        [
            SubLayer(name: "Eighths",   pulsesPerBeat: 2, volume: 0.5, enabled: false, frequency: 1_400),
            SubLayer(name: "Triplets",  pulsesPerBeat: 3, volume: 0.5, enabled: false, frequency: 1_600),
            SubLayer(name: "Sixteenths", pulsesPerBeat: 4, volume: 0.45, enabled: false, frequency: 1_800),
            SubLayer(name: "Quarters",  pulsesPerBeat: 1, volume: 0.5, enabled: false, frequency: 1_200)
        ]
    }
}
