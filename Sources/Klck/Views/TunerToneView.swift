import SwiftUI

struct TunerToneView: View {
    @EnvironmentObject private var model: MetronomeModel
    @EnvironmentObject private var tuner: Tuner

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TUNER & TONE")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(DB66.engrave)
                .tracking(1.5)

            tunerDisplay
            Divider().overlay(DB66.panelEdge)
            toneControls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Tuner

    private var tunerDisplay: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                Text(tuner.hasSignal ? tuner.noteName : "—")
                    .font(DB66.lcdFont(46))
                    .foregroundStyle(DB66.lcdInk)
                    .frame(minWidth: 110)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tuner.hasSignal ? String(format: "%.1f Hz", tuner.frequency) : "listening…")
                        .font(DB66.lcdFont(14))
                        .foregroundStyle(DB66.lcdInk)
                    Text(tuner.hasSignal ? String(format: "%+.0f cents", tuner.cents) : " ")
                        .font(DB66.lcdFont(13))
                        .foregroundStyle(inTune ? DB66.lcdInk : DB66.lcdInk.opacity(0.6))
                }
                Spacer()
            }
            centsMeter
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [DB66.lcdBack, DB66.lcdBackEdge],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.55), lineWidth: 3))
        )
        .overlay(alignment: .topTrailing) {
            Button(tuner.isListening ? "STOP" : "LISTEN") { tuner.toggle() }
                .buttonStyle(DeviceButtonStyle(
                    tint: tuner.isListening ? (DB66.startTop, DB66.startBot) : (DB66.btnTop, DB66.btnBot),
                    prominent: tuner.isListening))
                .padding(10)
        }
        .overlay(alignment: .bottom) {
            if tuner.permissionDenied {
                Text("Microphone access denied — enable it in System Settings ▸ Privacy.")
                    .font(.caption)
                    .foregroundStyle(DB66.ledAccent)
                    .padding(.bottom, 6)
            }
        }
    }

    private var inTune: Bool { tuner.hasSignal && abs(tuner.cents) < 5 }

    private var centsMeter: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(-50, min(50, tuner.cents))
            let x = w / 2 + CGFloat(clamped / 50) * (w / 2 - 10)
            ZStack(alignment: .leading) {
                Capsule().fill(DB66.lcdInk.opacity(0.18)).frame(height: 6)
                Rectangle().fill(DB66.lcdInk.opacity(0.5))
                    .frame(width: 2, height: 18)
                    .position(x: w / 2, y: 9)
                Circle()
                    .fill(inTune ? Color.green : DB66.lcdInk)
                    .frame(width: 18, height: 18)
                    .position(x: tuner.hasSignal ? x : w / 2, y: 9)
                    .animation(.easeOut(duration: 0.12), value: tuner.cents)
            }
        }
        .frame(height: 20)
    }

    // MARK: Tone generator

    private var toneControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Toggle("Tone", isOn: $model.toneEnabled)
                    .toggleStyle(.switch)
                    .fixedSize()

                Button { stepTone(-1) } label: { Image(systemName: "minus") }
                    .buttonStyle(DeviceButtonStyle())
                Text(MetronomeModel.noteName(for: model.toneFrequency))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(width: 56)
                Button { stepTone(1) } label: { Image(systemName: "plus") }
                    .buttonStyle(DeviceButtonStyle())

                Text(String(format: "%.1f Hz", model.toneFrequency))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DB66.engrave)
                Spacer()
                Button("A 440") { model.toneFrequency = 440 }
                    .buttonStyle(DeviceButtonStyle())
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary)
                Slider(value: $model.toneVolume, in: 0...1)
                Text("\(Int(model.toneVolume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    /// Move the tone by whole semitones on the equal-tempered scale.
    private func stepTone(_ semitones: Int) {
        let midi = (69 + 12 * log2(model.toneFrequency / 440)).rounded()
        let next = midi + Double(semitones)
        model.toneFrequency = 440 * pow(2, (next - 69) / 12)
    }
}
