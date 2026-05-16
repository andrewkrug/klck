import SwiftUI

@main
struct KlckApp: App {
    @StateObject private var model = MetronomeModel()

    var body: some Scene {
        WindowGroup("Klck") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
