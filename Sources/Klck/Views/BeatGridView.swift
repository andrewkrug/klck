import SwiftUI

struct BeatGridView: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Beats per measure")
                    .font(.headline)
                Spacer()
                Stepper(
                    "\(model.beatsPerCycle)",
                    value: $model.beatsPerCycle,
                    in: 1...16
                )
                .fixedSize()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: min(model.beatsPerCycle, 8)),
                spacing: 10
            ) {
                ForEach(0..<model.beatsPerCycle, id: \.self) { i in
                    Button {
                        model.cycleAccent(i)
                    } label: {
                        Text("\(i + 1)")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(color(for: i), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(foreground(for: i))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Tap a beat to cycle: Accent → Normal → Muted")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func state(_ i: Int) -> BeatAccent {
        guard i < model.accents.count else { return .normal }
        return BeatAccent(rawValue: model.accents[i]) ?? .normal
    }

    private func color(for i: Int) -> Color {
        switch state(i) {
        case .accent: return .accentColor
        case .normal: return Color.secondary.opacity(0.25)
        case .muted:  return Color.secondary.opacity(0.06)
        }
    }

    private func foreground(for i: Int) -> Color {
        switch state(i) {
        case .accent: return .white
        case .normal: return .primary
        case .muted:  return .secondary
        }
    }
}
