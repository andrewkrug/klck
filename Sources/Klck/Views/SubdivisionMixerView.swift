import SwiftUI

struct SubdivisionMixerView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBDIVISION LAYERS")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(1.5)

            ForEach($model.layers) { $layer in
                if isCompact {
                    compactRow(layer: $layer)
                } else {
                    wideRow(layer: $layer)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Regular (iPad / macOS): everything on a single line — the original layout.
    private func wideRow(layer: Binding<SubLayer>) -> some View {
        HStack(spacing: 14) {
            Toggle(isOn: layer.enabled) {
                Text(layer.wrappedValue.name)
                    .frame(width: 90, alignment: .leading)
            }
            .toggleStyle(.switch)

            Image(systemName: "speaker.wave.1")
                .foregroundStyle(.secondary)
                .opacity(layer.wrappedValue.enabled ? 1 : 0.3)

            Slider(value: layer.volume, in: 0...1)
                .disabled(!layer.wrappedValue.enabled)

            Text("\(Int(layer.wrappedValue.volume * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Picker("Sound", selection: layer.waveform) {
                ForEach(ClickWaveform.allCases) { wf in
                    Text(wf.label).tag(wf)
                }
            }
            .labelsHidden()
            .frame(width: 88)
            .disabled(!layer.wrappedValue.enabled)
        }
    }

    /// Compact (iPhone): two stacked rows so the picker doesn't get clipped.
    /// Row 1 is the on/off + name + level read-out; row 2 is the slider + tone.
    private func compactRow(layer: Binding<SubLayer>) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Toggle("", isOn: layer.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()

                Text(layer.wrappedValue.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text("\(Int(layer.wrappedValue.volume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(layer.wrappedValue.enabled ? 1 : 0.3)

                Slider(value: layer.volume, in: 0...1)
                    .disabled(!layer.wrappedValue.enabled)

                Picker("Sound", selection: layer.waveform) {
                    ForEach(ClickWaveform.allCases) { wf in
                        Text(wf.label).tag(wf)
                    }
                }
                .labelsHidden()
                .frame(width: 92)
                .disabled(!layer.wrappedValue.enabled)
            }
        }
        .padding(.vertical, 2)
    }
}
