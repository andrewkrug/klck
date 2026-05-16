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
}
