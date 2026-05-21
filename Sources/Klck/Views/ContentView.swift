import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var showMemory = false
    @State private var showSave = false
    @State private var saveName = ""
    @State private var flash = 0.0

    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        ZStack {
            DB66.chassis.ignoresSafeArea()

            GeometryReader { proxy in
                // 2-column whenever there's room: iPad Pro portrait, every
                // iPad in landscape. iPad mini portrait + iPhone fall back
                // to single column.
                let twoCol = hSize == .regular && proxy.size.width >= 900
                let singleColumnMax: CGFloat = isCompact ? .infinity : 720

                ScrollView {
                    Group {
                        if twoCol {
                            twoColumnLayout(width: proxy.size.width)
                        } else {
                            singleColumnLayout
                                .frame(maxWidth: singleColumnMax)
                        }
                    }
                    .padding(.horizontal, isCompact ? 22 : 24)
                    .padding(.vertical, isCompact ? 16 : 24)
                    .frame(maxWidth: .infinity)
                }
            }

            // Beat flash: bright accent on the downbeat, soft amber otherwise.
            if model.flashEnabled {
                (model.activeBeat == 0 ? DB66.ledAccent : DB66.ledBeat)
                    .opacity(flash)
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .tint(DB66.ledBeat)
        .onChange(of: model.beatPulse) { _ in
            guard model.flashEnabled, model.isRunning else { return }
            flash = model.activeBeat == 0 ? 0.32 : 0.14
            withAnimation(.easeOut(duration: 0.16)) { flash = 0.0 }
        }
        .sheet(isPresented: $showMemory) {
            MemorySheet().environmentObject(model)
        }
        .alert("Save Preset", isPresented: $showSave) {
            TextField("Preset name", text: $saveName)
            Button("Save") {
                model.savePreset(named: saveName)
                saveName = ""
            }
            Button("Cancel", role: .cancel) { saveName = "" }
        } message: {
            Text("Stores tempo, meter, accents, subdivisions, swing, and sound.")
        }
    }

    /// Single column — iPhone, iPad mini portrait, narrow iPad split-view.
    private var singleColumnLayout: some View {
        VStack(spacing: isCompact ? 12 : 18) {
            brandBar

            VStack(spacing: isCompact ? 10 : 14) {
                BeatLightsView()
                LCDView()
                TransportDeckView(showMemory: $showMemory, showSave: $showSave)
            }
            .devicePanel()

            BeatGridView().devicePanel()
            SubdivisionMixerView().devicePanel()
            PracticePanelView().devicePanel()
            TunerToneView().devicePanel()
        }
    }

    /// Two columns — iPad Pro portrait + every iPad in landscape. Left side
    /// is "performance" (what you watch while playing); right side is
    /// "configuration" (what you set up beforehand). Spacing is intentionally
    /// tighter than the single-column layout so landscape iPad fits more of
    /// the right column on screen without scrolling.
    private func twoColumnLayout(width: CGFloat) -> some View {
        VStack(spacing: 14) {
            brandBar

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    VStack(spacing: 12) {
                        BeatLightsView()
                        LCDView()
                        TransportDeckView(showMemory: $showMemory, showSave: $showSave)
                    }
                    .devicePanel()

                    BeatGridView().devicePanel()
                }

                VStack(spacing: 14) {
                    SubdivisionMixerView().devicePanel()
                    PracticePanelView().devicePanel()
                    TunerToneView().devicePanel()
                }
            }
        }
        // Leave a margin of chassis on either side of the content even on
        // very wide displays — beyond ~1280pt of content the layout would
        // start to feel sparse.
        .frame(maxWidth: min(width - 32, 1280))
    }

    private var brandBar: some View {
        HStack {
            Text("Klck")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            // Tagline only on iPad/macOS — it wraps badly at iPhone widths.
            if !isCompact {
                Text("OPEN-SOURCE · COMMUNITY-SUPPORTED METRONOME")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(DB66.engrave)
                    .tracking(2)
            }
            Spacer()
            Circle()
                .fill(model.isRunning ? DB66.ledAccent : DB66.ledOff)
                .frame(width: 10, height: 10)
                .shadow(color: model.isRunning ? DB66.ledAccent : .clear, radius: 5)
        }
        // Extra breathing room on iPhone so "Klck" + LED clear rounded
        // corners and the dynamic-island area on Pro models. The LED has a
        // 5pt shadow halo, so it needs noticeably more right-side margin.
        .padding(.leading, isCompact ? 8 : 4)
        .padding(.trailing, isCompact ? 14 : 4)
        .padding(.top, isCompact ? 6 : 0)
    }
}

/// Preset library, presented as the unit's "MEMORY" panel.
struct MemorySheet: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MEMORY")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(DeviceButtonStyle())
            }

            Picker("", selection: $tab) {
                Text("Presets").tag(0)
                Text("Setlists").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tab == 0 { presetsTab } else { SetlistTab() }
        }
        .padding(20)
        // Fixed pane on macOS; on iOS the sheet sizes itself to the device.
        #if os(macOS)
        .frame(width: 480, height: 520)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .background(DB66.chassis)
        .preferredColorScheme(.dark)
    }

    private var presetsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Preset name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("SAVE") {
                    model.savePreset(named: newName)
                    newName = ""
                }
                .buttonStyle(DeviceButtonStyle(tint: (DB66.startTop, DB66.startBot), prominent: true))
            }

            if model.presets.isEmpty {
                Text("No presets stored")
                    .font(.callout)
                    .foregroundStyle(DB66.engrave)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.presets) { preset in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(Int(preset.bpm)) BPM · \(preset.beatsPerCycle)/4")
                                        .font(.caption)
                                        .foregroundStyle(DB66.engrave)
                                }
                                Spacer()
                                if model.activeSetlist != nil {
                                    Button("+SET") { model.addToActiveSetlist(preset) }
                                        .buttonStyle(DeviceButtonStyle())
                                }
                                Button("LOAD") {
                                    model.apply(preset)
                                    dismiss()
                                }
                                .buttonStyle(DeviceButtonStyle())
                                Button {
                                    model.deletePreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(DeviceButtonStyle())
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(DB66.panel))
                        }
                    }
                }
            }
        }
    }
}

/// Setlist manager: create chains of presets and step through them.
struct SetlistTab: View {
    @EnvironmentObject private var model: MetronomeModel
    @State private var newSetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("New setlist name", text: $newSetName)
                    .textFieldStyle(.roundedBorder)
                Button("CREATE") {
                    model.createSetlist(named: newSetName)
                    newSetName = ""
                }
                .buttonStyle(DeviceButtonStyle(tint: (DB66.startTop, DB66.startBot), prominent: true))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.setlists) { set in
                        let active = set.id == model.activeSetlist?.id
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(active ? DB66.ledBeat : .white)
                                Text("\(set.items.count) presets")
                                    .font(.caption).foregroundStyle(DB66.engrave)
                            }
                            Spacer()
                            Button(active ? "ACTIVE" : "USE") {
                                model.activateSetlist(set)
                            }
                            .buttonStyle(DeviceButtonStyle(
                                tint: active ? (DB66.startTop, DB66.startBot) : (DB66.btnTop, DB66.btnBot),
                                prominent: active))
                            Button {
                                model.deleteSetlist(set)
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(DeviceButtonStyle())
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(DB66.panel))
                    }

                    if let set = model.activeSetlist {
                        Divider().overlay(DB66.panelEdge).padding(.vertical, 4)
                        Text("\(set.name.uppercased()) — ORDER")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(DB66.engrave).tracking(1.5)

                        if set.items.isEmpty {
                            Text("Add presets from the Presets tab (+SET).")
                                .font(.caption).foregroundStyle(DB66.engrave)
                                .padding(.vertical, 8)
                        }

                        ForEach(Array(set.items.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(idx == model.activeIndex ? DB66.ledBeat : DB66.engrave)
                                Text(model.preset(for: item.presetID)?.name ?? "‹deleted›")
                                    .foregroundStyle(.white)
                                Spacer()
                                Stepper(
                                    item.advanceAfterBars == 0
                                        ? "manual"
                                        : "\(item.advanceAfterBars) bars",
                                    value: Binding(
                                        get: { item.advanceAfterBars },
                                        set: { model.setAdvanceBars($0, forItemAt: idx) }),
                                    in: 0...64)
                                    .fixedSize()
                                Button {
                                    model.removeSetlistItem(at: IndexSet(integer: idx))
                                } label: { Image(systemName: "minus.circle") }
                                    .buttonStyle(DeviceButtonStyle())
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(idx == model.activeIndex ? DB66.panel : DB66.panel.opacity(0.5)))
                        }
                    }
                }
            }
        }
    }
}
