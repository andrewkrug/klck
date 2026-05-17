import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: MetronomeModel
    @State private var showMemory = false
    @State private var showSave = false
    @State private var saveName = ""
    @State private var flash = 0.0

    var body: some View {
        ZStack {
            DB66.chassis.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    brandBar

                    VStack(spacing: 14) {
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
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
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

    private var brandBar: some View {
        HStack {
            Text("Klck")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("OPEN-SOURCE · COMMUNITY-SUPPORTED METRONOME")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(2)
            Spacer()
            Circle()
                .fill(model.isRunning ? DB66.ledAccent : DB66.ledOff)
                .frame(width: 10, height: 10)
                .shadow(color: model.isRunning ? DB66.ledAccent : .clear, radius: 5)
        }
        .padding(.horizontal, 4)
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
        .frame(width: 480, height: 520)
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
