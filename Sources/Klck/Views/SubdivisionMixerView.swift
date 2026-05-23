import SwiftUI

/// Step-sequencer subdivision panel.
///
/// Per beat there are two independent step rows:
/// - **16th row** — 4 cells (the e / & / a positions). Cell 0 is the
///   downbeat itself (read-only; driven by the BEATS PER MEASURE accents).
/// - **Triplet row** — 3 cells (the eighth-note-triplet positions). Cell 0
///   is again the downbeat; cells 1 and 2 are the triplet "&"s.
///
/// Glyphs come from the Musical Symbols block (U+1D15F–U+1D161) — the
/// flag-count difference (none / one / two) reads clearly at 20-24pt where
/// the BMP "♩ ♪ ♬" trio looks almost identical.
///
/// Quick-set buttons let users skip the per-cell tap loop for the four most
/// common practice patterns: every 8th, every 16th, every triplet, or clear.
struct SubdivisionGridView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact }

    // Cell labels use the universal musician's count for each subdivision
    // position — clearer than music-notation glyphs at cell size (and side-
    // steps the SMP music-glyph rendering problem on iOS system fonts).
    // 16ths: beat-number, "e", "&", "a".
    // Triplets: beat-number, "trip", "let".
    private static let sixteenthLabels = ["", "e", "&", "a"]
    private static let tripletLabels   = ["", "trip", "let"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SUBDIVISION")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(DB66.engrave)
                    .tracking(1.5)
                Spacer()
            }

            quickSetBar

            VStack(spacing: isCompact ? 10 : 12) {
                ForEach(0..<model.beatsPerCycle, id: \.self) { beat in
                    beatBlock(beatIndex: beat)
                }
            }

            Text("Tap cells to add a click at that subdivision. The downbeat is driven by BEATS PER MEASURE above.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Quick-set bar

    private var quickSetBar: some View {
        HStack(spacing: 8) {
            Button("8ths")     { model.subdivisionApplyAllEighths() }
                .buttonStyle(DeviceButtonStyle())
            Button("16ths")    { model.subdivisionApplyAllSixteenths() }
                .buttonStyle(DeviceButtonStyle())
            Button("Triplets") { model.subdivisionApplyAllTriplets() }
                .buttonStyle(DeviceButtonStyle())
            Spacer()
            if hasAnyCellOn {
                Button("CLEAR") { model.subdivisionClearAll() }
                    .buttonStyle(DeviceButtonStyle())
            }
        }
    }

    private var hasAnyCellOn: Bool {
        model.subdivisionGrid.contains(true) || model.tripletGrid.contains(true)
    }

    // MARK: A single beat = label + two step rows

    private func beatBlock(beatIndex: Int) -> some View {
        HStack(alignment: .center, spacing: isCompact ? 8 : 10) {
            beatLabel(beatIndex: beatIndex)
            VStack(spacing: 4) {
                stepRow(beatIndex: beatIndex,
                        labels: Self.sixteenthLabels,
                        isActive: { gridIdx in model.subdivisionGrid[safe: gridIdx] ?? false },
                        onTap: { gridIdx in model.toggleSubdivisionCell(gridIdx) },
                        gridBase: beatIndex * 4)
                stepRow(beatIndex: beatIndex,
                        labels: Self.tripletLabels,
                        isActive: { gridIdx in model.tripletGrid[safe: gridIdx] ?? false },
                        onTap: { gridIdx in model.toggleTripletCell(gridIdx) },
                        gridBase: beatIndex * 3)
            }
        }
    }

    private func beatLabel(beatIndex: Int) -> some View {
        Text("\(beatIndex + 1)")
            .font(.system(size: isCompact ? 14 : 16, weight: .heavy, design: .rounded))
            .foregroundStyle(DB66.engrave)
            .frame(width: isCompact ? 20 : 24, alignment: .trailing)
    }

    // MARK: One step row (variable cell count)

    private func stepRow(beatIndex: Int,
                         labels: [String],
                         isActive: @escaping (Int) -> Bool,
                         onTap: @escaping (Int) -> Void,
                         gridBase: Int) -> some View {
        HStack(spacing: isCompact ? 6 : 8) {
            ForEach(0..<labels.count, id: \.self) { sub in
                cell(sub: sub,
                     beatIndex: beatIndex,
                     gridIndex: gridBase + sub,
                     label: labels[sub],
                     active: isActive(gridBase + sub),
                     onTap: onTap)
            }
        }
    }

    @ViewBuilder
    private func cell(sub: Int,
                      beatIndex: Int,
                      gridIndex: Int,
                      label: String,
                      active: Bool,
                      onTap: @escaping (Int) -> Void) -> some View {
        let isDownbeat = sub == 0
        // Downbeat cell shows the beat number (matches the BEATS PER MEASURE
        // row), read-only — that beat's click is driven by `accents`.
        let displayText = isDownbeat ? "\(beatIndex + 1)" : label
        if isDownbeat {
            cellShape(active: true)
                .overlay(noteLabel(text: displayText, isBeat: true, active: true))
                .opacity(0.5)
        } else {
            Button { onTap(gridIndex) } label: {
                cellShape(active: active)
                    .overlay(noteLabel(text: displayText, isBeat: false, active: active))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Beat \(beatIndex + 1) \(label), \(active ? "on" : "off")")
        }
    }

    private func cellShape(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(active ? Color.accentColor : DB66.btnTop.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(active ? Color.accentColor.opacity(0.9) : DB66.panelEdge,
                                  lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 30 : 34)
    }

    private func noteLabel(text: String, isBeat: Bool, active: Bool) -> some View {
        Text(text)
            .font(.system(size: isCompact ? 14 : 16,
                          weight: isBeat ? .heavy : .semibold,
                          design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(active ? .white : DB66.engrave)
    }
}

/// Back-compat alias so existing ContentView call sites keep compiling.
typealias SubdivisionMixerView = SubdivisionGridView

// MARK: Tiny convenience extension for safe indexing

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
