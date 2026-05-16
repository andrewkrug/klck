import SwiftUI

@main
struct KlckApp: App {
    @StateObject private var model = MetronomeModel()

    var body: some Scene {
        WindowGroup("Klck") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 560, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 620, height: 880)
    }
}
