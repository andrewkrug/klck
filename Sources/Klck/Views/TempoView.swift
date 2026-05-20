import SwiftUI

/// The Dr. Beat–style LCD: backlit pale-green glass with dark segment "ink".
struct LCDView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact }

    private var bpmDigits: String {
        String(format: "%3d", Int(model.bpm))
    }

    var body: some View {
        VStack(spacing: isCompact ? 6 : 10) {
            // Status row
            HStack {
                Text("TEMPO")
                Spacer()
                if let status = model.setlistStatus {
                    Text(status)
                    Text("·")
                }
                Text(model.isRunning ? "▶ RUN" : "■ STOP")
            }
            .font(DB66.lcdFont(isCompact ? 11 : 13))
            .foregroundStyle(DB66.lcdInk)

            // Big tempo readout — scales with available width.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(bpmDigits)
                    .foregroundStyle(DB66.lcdInk)
                    .font(DB66.lcdFont(isCompact ? 60 : 76))

                VStack(alignment: .leading, spacing: 2) {
                    Text("BPM")
                        .font(DB66.lcdFont(isCompact ? 13 : 15))
                    Circle()
                        .fill(beatDotOn ? DB66.lcdInk : DB66.lcdInkDim)
                        .frame(width: 12, height: 12)
                        .animation(.easeOut(duration: 0.07), value: model.beatPulse)
                }
                .foregroundStyle(DB66.lcdInk)
            }

            // Segmented info strip — 4 fields side-by-side. Font drops on
            // compact so "BEAT 4/4 | SUBDIV OFF | SWING 0% | TIMER --:--"
            // doesn't push past iPhone-SE width (375pt).
            HStack(spacing: 0) {
                lcdField("BEAT", "\(model.beatsPerCycle)/4")
                lcdDivider
                lcdField("SUBDIV", subdivLabel)
                lcdDivider
                lcdField("SWING", "\(Int(model.swing * 100))%")
                lcdDivider
                lcdField("TIMER", timerLabel)
            }
            .font(DB66.lcdFont(isCompact ? 10 : 13))
            .foregroundStyle(DB66.lcdInk)
        }
        .padding(.horizontal, isCompact ? 10 : 22)
        .padding(.vertical, isCompact ? 12 : 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(
                    colors: [DB66.lcdBack, DB66.lcdBackEdge],
                    startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.55), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
        )
    }

    private var beatDotOn: Bool {
        model.isRunning && model.beatPulse % 2 == 0
    }

    private var subdivLabel: String {
        if let active = model.layers.first(where: { $0.enabled }) {
            return active.name.uppercased().prefix(4).description
        }
        return "OFF"
    }

    private var timerLabel: String {
        guard model.timerEnabled else { return "--:--" }
        let t = Int(model.isRunning ? model.timerRemaining : Double(model.timerMinutes * 60))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func lcdField(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(DB66.lcdFont(isCompact ? 8 : 10)).foregroundStyle(DB66.lcdInk.opacity(0.55))
            Text(value).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var lcdDivider: some View {
        Rectangle().fill(DB66.lcdInk.opacity(0.25)).frame(width: 1, height: isCompact ? 20 : 26)
    }
}
