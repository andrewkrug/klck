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

    /// Strobe-tuner style needle gauge. The needle pivots from the bottom of
    /// the gauge: vertical = perfectly in tune, swung left = flat, right =
    /// sharp. The full ±70° swing maps to ±50 cents.
    private var centsMeter: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h - 2)
            let radius = min(w / 2 - 8, h - 6)
            let clamped = max(-50, min(50, tuner.cents))
            let needleAngle = Double(clamped) / 50 * 70

            ZStack {
                // Backdrop arc (the gauge face).
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(-160), endAngle: .degrees(-20),
                             clockwise: false)
                }
                .stroke(DB66.lcdInk.opacity(0.22), style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // "In tune" green segment (~±5 cents).
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(-97), endAngle: .degrees(-83),
                             clockwise: false)
                }
                .stroke(Color.green.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round))

                // Major tick marks at -50, -25, 0, +25, +50 cents.
                ForEach([-50, -25, 0, 25, 50], id: \.self) { tick in
                    tickMark(cents: tick, center: center, radius: radius,
                             length: tick == 0 ? 12 : 8,
                             weight: tick == 0 ? 2.5 : 1.5)
                }

                // Needle.
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: h - 2))
                    p.addLine(to: CGPoint(x: w / 2, y: h - radius - 2))
                }
                .stroke(inTune ? Color.green : DB66.lcdInk,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(tuner.hasSignal ? needleAngle : 0),
                                anchor: UnitPoint(x: 0.5, y: (h - 2) / h))
                .animation(.spring(response: 0.18, dampingFraction: 0.75),
                           value: tuner.cents)
                .opacity(tuner.hasSignal ? 1 : 0.35)

                // Pivot cap.
                Circle()
                    .fill(DB66.lcdInk)
                    .frame(width: 9, height: 9)
                    .position(center)

                // Labels.
                Text("♭").font(DB66.lcdFont(11)).foregroundStyle(DB66.lcdInk.opacity(0.5))
                    .position(x: center.x - radius - 2, y: center.y - 4)
                Text("♯").font(DB66.lcdFont(11)).foregroundStyle(DB66.lcdInk.opacity(0.5))
                    .position(x: center.x + radius + 2, y: center.y - 4)
            }
        }
        .frame(height: 80)
    }

    /// Draws one tick at the given cents value along the gauge arc.
    private func tickMark(cents: Int, center: CGPoint, radius: CGFloat,
                          length: CGFloat, weight: CGFloat) -> some View {
        let angle = Double(cents) / 50 * 70 - 90   // gauge top = 0 cents
        let rad = angle * .pi / 180
        let inner = CGPoint(
            x: center.x + (radius - length) * CGFloat(cos(rad)),
            y: center.y + (radius - length) * CGFloat(sin(rad))
        )
        let outer = CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
        return Path { p in
            p.move(to: inner)
            p.addLine(to: outer)
        }
        .stroke(DB66.lcdInk.opacity(0.7),
                style: StrokeStyle(lineWidth: weight, lineCap: .round))
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
