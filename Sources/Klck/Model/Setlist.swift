import Foundation

/// One stop in a setlist: a reference to a saved preset, with an optional
/// auto-advance after a number of bars (0 = advance manually).
struct SetlistItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var presetID: UUID
    var advanceAfterBars: Int = 0
}

/// An ordered chain of presets for a song, gig, or practice routine.
struct Setlist: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var items: [SetlistItem] = []
}
