import SwiftUI

/// The button cluster beneath the LCD: tempo nudge, slider, tap, start/stop.
struct TransportDeckView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Binding var showMemory: Bool
    @Binding var showSave: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button("TEMPO −") { model.setBPM(model.bpm - 1) }
                    .buttonStyle(DeviceButtonStyle())
                Slider(
                    value: Binding(get: { model.bpm }, set: { model.setBPM($0) }),
                    in: model.minBPM...model.maxBPM
                )
                .tint(DB66.ledBeat)
                Button("TEMPO +") { model.setBPM(model.bpm + 1) }
                    .buttonStyle(DeviceButtonStyle())
            }

            HStack(spacing: 10) {
                Button(model.isRunning ? "STOP" : "START") {
                    model.toggle()
                }
                .buttonStyle(DeviceButtonStyle(
                    tint: model.isRunning
                        ? (DB66.startTop, DB66.startBot)
                        : (DB66.btnTop, DB66.btnBot),
                    prominent: true))
                .keyboardShortcut(.space, modifiers: [])

                Button("TAP") { model.tap() }
                    .buttonStyle(DeviceButtonStyle())
                    .keyboardShortcut("t", modifiers: [])

                Button(model.flashEnabled ? "FLASH ON" : "FLASH OFF") {
                    model.flashEnabled.toggle()
                }
                .buttonStyle(DeviceButtonStyle(
                    tint: model.flashEnabled
                        ? (DB66.startTop, DB66.startBot)
                        : (DB66.btnTop, DB66.btnBot),
                    prominent: model.flashEnabled))

                Spacer()

                Button("SAVE") { showSave = true }
                    .buttonStyle(DeviceButtonStyle())

                Button("MEMORY") { showMemory = true }
                    .buttonStyle(DeviceButtonStyle())
            }
        }
    }
}
