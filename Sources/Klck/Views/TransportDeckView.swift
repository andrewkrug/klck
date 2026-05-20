import SwiftUI

/// The button cluster beneath the LCD: tempo nudge, slider, tap, start/stop.
///
/// Layout adapts to size class:
/// - **Compact** (iPhone portrait): two-row button grid, tighter spacing.
/// - **Regular** (iPad / macOS): single-row layout with the original spacing.
struct TransportDeckView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize
    @Binding var showMemory: Bool
    @Binding var showSave: Bool

    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            // Tempo slider row — works at every width.
            HStack(spacing: 10) {
                Button("−") { model.setBPM(model.bpm - 1) }
                    .buttonStyle(DeviceButtonStyle())
                Slider(
                    value: Binding(get: { model.bpm }, set: { model.setBPM($0) }),
                    in: model.minBPM...model.maxBPM
                )
                .tint(DB66.ledBeat)
                Button("+") { model.setBPM(model.bpm + 1) }
                    .buttonStyle(DeviceButtonStyle())
            }

            if isCompact {
                compactButtonGrid
            } else {
                wideButtonRow
            }
        }
    }

    // MARK: Buttons

    private var startStopButton: some View {
        Button(model.isRunning ? "STOP" : "START") { model.toggle() }
            .buttonStyle(DeviceButtonStyle(
                tint: model.isRunning ? (DB66.startTop, DB66.startBot)
                                      : (DB66.btnTop, DB66.btnBot),
                prominent: true))
            .keyboardShortcut(.space, modifiers: [])
            .frame(maxWidth: .infinity)
    }

    private var tapButton: some View {
        Button("TAP") { model.tap() }
            .buttonStyle(DeviceButtonStyle())
            .keyboardShortcut("t", modifiers: [])
            .frame(maxWidth: .infinity)
    }

    private var flashButton: some View {
        Button(model.flashEnabled ? "FLASH" : "FLASH") { model.flashEnabled.toggle() }
            .buttonStyle(DeviceButtonStyle(
                tint: model.flashEnabled ? (DB66.startTop, DB66.startBot)
                                         : (DB66.btnTop, DB66.btnBot),
                prominent: model.flashEnabled))
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var setlistPrevNext: some View {
        if model.activeSetlist != nil {
            Button("◀") { model.setlistPrev() }
                .buttonStyle(DeviceButtonStyle())
                .disabled(!model.canSetlistPrev)
                .keyboardShortcut("[", modifiers: [])
                .frame(maxWidth: .infinity)
            Button("▶") { model.setlistNext() }
                .buttonStyle(DeviceButtonStyle())
                .disabled(!model.canSetlistNext)
                .keyboardShortcut("]", modifiers: [])
                .frame(maxWidth: .infinity)
        }
    }

    private var saveButton: some View {
        Button("SAVE") { showSave = true }
            .buttonStyle(DeviceButtonStyle())
            .frame(maxWidth: .infinity)
    }

    private var memoryButton: some View {
        Button("MEMORY") { showMemory = true }
            .buttonStyle(DeviceButtonStyle())
            .frame(maxWidth: .infinity)
    }

    // MARK: Layout variants

    /// Regular (iPad / macOS): everything in one row, with a Spacer between
    /// the always-on transport cluster and the right-side actions.
    private var wideButtonRow: some View {
        HStack(spacing: 10) {
            startStopButton
            tapButton
            flashButton
            Spacer()
            setlistPrevNext
            saveButton
            memoryButton
        }
    }

    /// Compact (iPhone): two stacked rows so nothing gets clipped.
    private var compactButtonGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                startStopButton
                tapButton
                flashButton
            }
            HStack(spacing: 8) {
                setlistPrevNext
                saveButton
                memoryButton
            }
        }
    }
}
