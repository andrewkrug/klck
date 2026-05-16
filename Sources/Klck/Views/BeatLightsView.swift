import SwiftUI

/// The row of beat indicator LEDs across the top of the unit, Dr. Beat style.
struct BeatLightsView: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<model.beatsPerCycle, id: \.self) { i in
                let accent = (i < model.accents.count ? model.accents[i] : 1) == 2
                let on = model.activeBeat == i && model.isRunning
                Circle()
                    .fill(color(on: on, accent: accent))
                    .frame(width: accent ? 20 : 16, height: accent ? 20 : 16)
                    .overlay(
                        Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(
                        color: on ? (accent ? DB66.ledAccent : DB66.ledBeat).opacity(0.9) : .clear,
                        radius: on ? 9 : 0
                    )
                    .animation(.easeOut(duration: 0.06), value: model.beatPulse)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }

    private func color(on: Bool, accent: Bool) -> Color {
        guard on else { return DB66.ledOff }
        return accent ? DB66.ledAccent : DB66.ledBeat
    }
}
