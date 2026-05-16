import SwiftUI

struct TempoView: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(model.bpm))")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    model.setBPM(model.bpm - 1)
                } label: {
                    Image(systemName: "minus").frame(width: 28, height: 28)
                }
                Slider(
                    value: Binding(
                        get: { model.bpm },
                        set: { model.setBPM($0) }
                    ),
                    in: model.minBPM...model.maxBPM
                )
                Button {
                    model.setBPM(model.bpm + 1)
                } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28)
                }
            }
            .frame(maxWidth: 480)

            HStack(spacing: 16) {
                Button(action: model.toggle) {
                    Label(
                        model.isRunning ? "Stop" : "Start",
                        systemImage: model.isRunning ? "stop.fill" : "play.fill"
                    )
                    .frame(width: 120)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isRunning ? .red : .accentColor)
                .keyboardShortcut(.space, modifiers: [])

                Button(action: model.tap) {
                    Label("Tap", systemImage: "hand.tap.fill")
                        .frame(width: 100)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("t", modifiers: [])
            }
        }
    }
}
