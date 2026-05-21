import SwiftUI

struct PracticePanelView: View {
    @EnvironmentObject private var model: MetronomeModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FEEL & PRACTICE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(1.5)

            VStack(alignment: .leading, spacing: 6) {
                Text("Swing \(Int(model.swing * 100))%")
                    .font(.subheadline)
                Slider(value: $model.swing, in: 0...0.6)
                    .frame(maxWidth: isCompact ? .infinity : 320)
            }

            // Two pickers per row on iPad/macOS; one per row on iPhone.
            adaptiveRow(spacing: isCompact ? 12 : 24) {
                soundPicker("Accent sound", selection: $model.accentSound)
                soundPicker("Beat sound", selection: $model.beatSound)
            }
            adaptiveRow(spacing: isCompact ? 12 : 24) {
                soundAndVolume("16th row",
                               selection: $model.subdivisionSound,
                               volume: $model.subdivisionVolume)
                soundAndVolume("Triplet row",
                               selection: $model.tripletSound,
                               volume: $model.tripletVolume)
            }

            Toggle("Flash screen on the beat (brighter on the downbeat)",
                   isOn: $model.flashEnabled)
                .toggleStyle(.switch)
                .font(.subheadline)

            DisclosureGroup {
                adaptiveRow {
                    Toggle("Enable", isOn: $model.quietEnabled)
                        .toggleStyle(.switch)
                    Stepper("Play \(model.quietPlayBars) bars",
                            value: $model.quietPlayBars, in: 1...32)
                        .fixedSize()
                    Stepper("Mute \(model.quietMuteBars) bars",
                            value: $model.quietMuteBars, in: 1...32)
                        .fixedSize()
                }
                .padding(.top, 6)
            } label: {
                Label("Quiet Count", systemImage: "speaker.slash")
                    .font(.subheadline.weight(.medium))
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Ramp tempo while running", isOn: $model.rampEnabled)
                        .toggleStyle(.switch)
                    adaptiveRow {
                        bpmField("From", $model.rampStartBPM)
                        bpmField("To", $model.rampTargetBPM)
                        Stepper("+\(Int(model.rampStepBPM)) BPM",
                                value: $model.rampStepBPM, in: 1...30)
                            .fixedSize()
                        Stepper("every \(model.rampEveryBars) bars",
                                value: $model.rampEveryBars, in: 1...32)
                            .fixedSize()
                    }
                    .disabled(!model.rampEnabled)
                }
                .padding(.top, 6)
            } label: {
                Label("Tempo Trainer", systemImage: "speedometer")
                    .font(.subheadline.weight(.medium))
            }

            DisclosureGroup {
                adaptiveRow {
                    Toggle("Enable", isOn: $model.timerEnabled)
                        .toggleStyle(.switch)
                    Stepper("\(model.timerMinutes) min",
                            value: $model.timerMinutes, in: 1...120)
                        .fixedSize()
                    if model.isRunning && model.timerEnabled {
                        Text(timeString(model.timerRemaining))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 6)
            } label: {
                Label("Practice Timer", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bpmField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number)
                .frame(width: 56)
                .textFieldStyle(.roundedBorder)
            Text("BPM").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func soundPicker(_ title: String,
                             selection: Binding<ClickWaveform>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            Picker(title, selection: selection) {
                ForEach(ClickWaveform.allCases) { wf in
                    Text(wf.label).tag(wf)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: isCompact ? .infinity : 240)
        }
    }

    /// Like `soundPicker` but with an inline volume slider beneath the
    /// waveform picker. Used for the subdivision rows where the player
    /// usually wants to dial them under the main beat.
    private func soundAndVolume(_ title: String,
                                selection: Binding<ClickWaveform>,
                                volume: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Int(volume.wrappedValue * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Picker(title, selection: selection) {
                ForEach(ClickWaveform.allCases) { wf in
                    Text(wf.label).tag(wf)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: isCompact ? .infinity : 240)

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1")
                    .foregroundStyle(.secondary)
                Slider(value: volume, in: 0...1)
                    .frame(maxWidth: isCompact ? .infinity : 240)
            }
        }
    }

    /// HStack on iPad/macOS, VStack on iPhone — keeps wide control rows from
    /// clipping at iPhone-SE widths without bloating iPad/macOS layouts.
    @ViewBuilder
    private func adaptiveRow<Content: View>(
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: spacing) { content() }
        } else {
            HStack(spacing: spacing) { content() }
        }
    }
}
