import SwiftUI

struct PracticePanelView: View {
    @EnvironmentObject private var model: MetronomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FEEL & PRACTICE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(1.5)

            // Swing + click sound
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Swing \(Int(model.swing * 100))%")
                        .font(.subheadline)
                    Slider(value: $model.swing, in: 0...0.6)
                        .frame(width: 220)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Click sound").font(.subheadline)
                    Picker("Click sound", selection: $model.clickSound) {
                        ForEach(ClickWaveform.allCases) { wf in
                            Text(wf.label).tag(wf)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 260)
                }
            }

            Toggle("Flash screen on the beat (brighter on the downbeat)",
                   isOn: $model.flashEnabled)
                .toggleStyle(.switch)
                .font(.subheadline)

            DisclosureGroup {
                HStack(spacing: 16) {
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
                    HStack(spacing: 14) {
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
                HStack(spacing: 16) {
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
}
