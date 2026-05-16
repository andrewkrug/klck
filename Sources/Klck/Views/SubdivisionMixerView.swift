import SwiftUI

struct SubdivisionMixerView: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBDIVISION LAYERS")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(1.5)

            ForEach($model.layers) { $layer in
                HStack(spacing: 14) {
                    Toggle(isOn: $layer.enabled) {
                        Text(layer.name)
                            .frame(width: 90, alignment: .leading)
                    }
                    .toggleStyle(.switch)

                    Image(systemName: "speaker.wave.1")
                        .foregroundStyle(.secondary)
                        .opacity(layer.enabled ? 1 : 0.3)

                    Slider(value: $layer.volume, in: 0...1)
                        .disabled(!layer.enabled)

                    Text("\(Int(layer.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)

                    Picker("Sound", selection: $layer.waveform) {
                        ForEach(ClickWaveform.allCases) { wf in
                            Text(wf.label).tag(wf)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 88)
                    .disabled(!layer.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
