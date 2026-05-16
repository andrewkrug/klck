import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: MetronomeModel
    @State private var showSavePrompt = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationSplitView {
            PresetsSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            ScrollView {
                VStack(spacing: 28) {
                    TempoView()
                    Divider()
                    BeatGridView()
                    Divider()
                    SubdivisionMixerView()
                    Divider()
                    PracticePanelView()
                    Divider()
                    masterControls
                }
                .padding(28)
            }
            .navigationTitle("Klck")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPresetName = ""
                        showSavePrompt = true
                    } label: {
                        Label("Save Preset", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .alert("Save Preset", isPresented: $showSavePrompt) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") { model.savePreset(named: newPresetName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stores tempo, meter, accents, and subdivision layers.")
        }
    }

    private var masterControls: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
            Slider(value: $model.masterVolume, in: 0...1)
            Text("\(Int(model.masterVolume * 100))%")
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 420)
    }
}
