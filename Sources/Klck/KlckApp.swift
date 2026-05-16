import SwiftUI

@main
struct KlckApp: App {
    @StateObject private var model = MetronomeModel()
    @StateObject private var tuner = Tuner()

    var body: some Scene {
        WindowGroup("Klck") {
            ContentView()
                .environmentObject(model)
                .environmentObject(tuner)
                .frame(minWidth: 560, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 620, height: 880)
    }
}
