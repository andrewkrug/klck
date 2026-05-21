import SwiftUI

/// Step-sequencer style subdivision grid. Each beat in the measure becomes
/// a row of four cells — the four 16th-note positions. The first cell of
/// every beat shows the beat number (it's driven by the BEATS PER MEASURE
/// accent grid, not by this view), and the other three cells are toggleable
/// "e" / "and" / "a" subdivisions.
///
/// Filename retained as SubdivisionMixerView for git history; the type is
/// renamed via a typealias so the existing call sites in `ContentView`
/// don't have to change.
struct SubdivisionGridView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SUBDIVISION")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(DB66.engrave)
                    .tracking(1.5)
                Spacer()
                if model.subdivisionGrid.contains(true) {
                    Button("CLEAR") {
                        model.subdivisionGrid = Array(repeating: false,
                                                       count: model.subdivisionGrid.count)
                    }
                    .buttonStyle(DeviceButtonStyle())
                }
            }

            VStack(spacing: isCompact ? 6 : 8) {
                ForEach(0..<model.beatsPerCycle, id: \.self) { beat in
                    beatRow(beatIndex: beat)
                }
            }

            Text("Tap a cell to add the 16th- or 8th-note subdivision. The first cell of each beat is driven by the BEATS PER MEASURE row above.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: One beat = 4 cells

    private func beatRow(beatIndex: Int) -> some View {
        HStack(spacing: isCompact ? 6 : 10) {
            beatLabel(beatIndex: beatIndex)
            ForEach(0..<4, id: \.self) { sub in
                cell(beatIndex: beatIndex, subIndex: sub)
            }
        }
    }

    private func beatLabel(beatIndex: Int) -> some View {
        Text("\(beatIndex + 1)")
            .font(.system(size: isCompact ? 12 : 13, weight: .heavy, design: .rounded))
            .foregroundStyle(DB66.engrave)
            .frame(width: isCompact ? 18 : 24, alignment: .trailing)
    }

    @ViewBuilder
    private func cell(beatIndex: Int, subIndex: Int) -> some View {
        let gridIndex = beatIndex * 4 + subIndex
        let isQuarter = subIndex == 0
        let active = model.subdivisionGrid.indices.contains(gridIndex)
            ? model.subdivisionGrid[gridIndex]
            : false

        // Quarter cell is read-only: it just shows which beat owns the row,
        // mirroring the accent the user set in BEATS PER MEASURE.
        if isQuarter {
            cellShape(active: true, isQuarter: true)
                .overlay(
                    Text(noteIcon(for: subIndex))
                        .font(.system(size: isCompact ? 20 : 24, weight: .black))
                        .foregroundStyle(DB66.engrave)
                )
                .opacity(0.55)
        } else {
            Button {
                model.toggleSubdivisionCell(gridIndex)
            } label: {
                cellShape(active: active, isQuarter: false)
                    .overlay(
                        Text(noteIcon(for: subIndex))
                            .font(.system(size: isCompact ? 20 : 24, weight: .black))
                            .foregroundStyle(active ? .white : DB66.engrave)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(beatIndex: beatIndex, subIndex: subIndex, active: active))
        }
    }

    private func cellShape(active: Bool, isQuarter: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(active ? Color.accentColor : DB66.btnTop.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(active ? Color.accentColor.opacity(0.9)
                                          : DB66.panelEdge.opacity(0.9),
                                  lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 40 : 46)
    }

    /// Note-value icon for the cell at this sub-position.
    /// - 0 → quarter (♩)
    /// - 2 → eighth offbeat (♪, the "and")
    /// - 1 or 3 → sixteenth offbeats (♬, the "e" / "a")
    private func noteIcon(for subIndex: Int) -> String {
        switch subIndex {
        case 0: return "♩"
        case 2: return "♪"
        default: return "♬"
        }
    }

    private func accessibilityLabel(beatIndex: Int, subIndex: Int, active: Bool) -> String {
        let position: String = {
            switch subIndex {
            case 1: return "e of \(beatIndex + 1)"
            case 2: return "and of \(beatIndex + 1)"
            case 3: return "a of \(beatIndex + 1)"
            default: return "beat \(beatIndex + 1)"
            }
        }()
        return "\(position), \(active ? "on" : "off")"
    }
}

/// Back-compat alias so existing call sites that still say
/// `SubdivisionMixerView` continue to compile.
typealias SubdivisionMixerView = SubdivisionGridView
