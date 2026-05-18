import SwiftUI

@main
struct KlckApp: App {
    @StateObject private var model = MetronomeModel()
    @StateObject private var tuner = Tuner()

    var body: some Scene {
        WindowGroup("Klck") {
            content
        }
        #if os(macOS)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 620, height: 880)
        #endif
    }

    private var content: some View {
        let view = ContentView()
            .environmentObject(model)
            .environmentObject(tuner)
        #if os(macOS)
        // On macOS the window is free-floating, so pin a usable minimum size.
        // On iOS the scene fills the device; ContentView scrolls to fit.
        return view.frame(minWidth: 560, minHeight: 720)
        #else
        return view
        #endif
    }
}
