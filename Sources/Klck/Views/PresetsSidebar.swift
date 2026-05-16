import SwiftUI

struct PresetsSidebar: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        List {
            Section("Presets") {
                if model.presets.isEmpty {
                    Text("No presets yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.presets) { preset in
                    Button {
                        model.apply(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.body.weight(.medium))
                            Text("\(Int(preset.bpm)) BPM · \(preset.beatsPerCycle)/4")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.deletePreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
