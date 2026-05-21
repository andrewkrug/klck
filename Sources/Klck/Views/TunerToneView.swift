import SwiftUI

struct TunerToneView: View {
    @EnvironmentObject private var model: MetronomeModel
    @EnvironmentObject private var tuner: Tuner
    @State private var showFullscreenTuner = false

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
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullscreenTuner) {
            FullscreenTunerView()
                .environmentObject(tuner)
        }
        #else
        .sheet(isPresented: $showFullscreenTuner) {
            FullscreenTunerView()
                .environmentObject(tuner)
        }
        #endif
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
                    Text(tunerStatusText)
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
            HStack(spacing: 6) {
                Button { showFullscreenTuner = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(DeviceButtonStyle())
                .accessibilityLabel("Full screen tuner")

                Button(tuner.isListening ? "STOP" : "LISTEN") { tuner.toggle() }
                    .buttonStyle(DeviceButtonStyle(
                        tint: tuner.isListening ? (DB66.startTop, DB66.startBot) : (DB66.btnTop, DB66.btnBot),
                        prominent: tuner.isListening))
            }
            .padding(10)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 2) {
                if tuner.permissionDenied {
                    Text("Microphone access denied — enable it in Settings ▸ Privacy & Security ▸ Microphone.")
                        .font(.caption)
                        .foregroundStyle(DB66.ledAccent)
                } else if let error = tuner.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(DB66.ledAccent)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }

    private var inTune: Bool { tuner.hasSignal && abs(tuner.cents) < 5 }

    /// Three states: actively reading pitch, listening for one, or idle.
    private var tunerStatusText: String {
        if tuner.hasSignal {
            return String(format: "%.1f Hz", tuner.frequency)
        } else if tuner.isListening {
            return "listening…"
        } else {
            return "tap LISTEN to tune"
        }
    }

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
            // Top row: toggle + note stepper. Always fits at iPhone-SE width.
            HStack(spacing: 10) {
                Toggle("Tone", isOn: $model.toneEnabled)
                    .toggleStyle(.switch)
                    .fixedSize()

                Spacer(minLength: 4)

                Button { stepTone(-1) } label: { Image(systemName: "minus") }
                    .buttonStyle(DeviceButtonStyle())
                Text(MetronomeModel.noteName(for: model.toneFrequency))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .frame(minWidth: 48)
                    .lineLimit(1)
                Button { stepTone(1) } label: { Image(systemName: "plus") }
                    .buttonStyle(DeviceButtonStyle())

                Spacer(minLength: 4)

                Button("A 440") { model.toneFrequency = 440 }
                    .buttonStyle(DeviceButtonStyle())
            }

            // Second informational row: current Hz reading, always visible.
            Text(String(format: "%.1f Hz", model.toneFrequency))
                .font(.caption.monospacedDigit())
                .foregroundStyle(DB66.engrave)
                .frame(maxWidth: .infinity, alignment: .leading)

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

/// Maximized tuner view — presented as a full-screen cover on iOS and a
/// sheet on macOS. Reserves the whole screen for the readout so a player
/// across the room can read it while tuning. The needle gauge is drawn at
/// the same shape as the inline gauge in `TunerToneView`, but the stroke
/// widths and tick lengths scale with the available radius so it looks
/// proportionate at any size.
struct FullscreenTunerView: View {
    @EnvironmentObject private var tuner: Tuner
    @Environment(\.dismiss) private var dismiss

    private var inTune: Bool { tuner.hasSignal && abs(tuner.cents) < 5 }

    private var noteText: String { tuner.hasSignal ? tuner.noteName : "—" }
    private var hzText: String { tuner.hasSignal ? String(format: "%.1f", tuner.frequency) : "—" }
    private var centsText: String { tuner.hasSignal ? String(format: "%+.0f", tuner.cents) : "—" }

    var body: some View {
        ZStack {
            DB66.chassis.ignoresSafeArea()

            VStack(spacing: 18) {
                // Close affordance.
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .accessibilityLabel("Close fullscreen tuner")
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // LCD-style readout card.
                VStack(spacing: 10) {
                    Text(noteText)
                        .font(DB66.lcdFont(160))
                        .foregroundStyle(DB66.lcdInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 48) {
                        readoutBlock(label: "FREQUENCY", value: hzText, suffix: "Hz")
                        readoutBlock(label: "CENTS", value: centsText, suffix: "¢",
                                     valueColor: inTune ? .green : DB66.lcdInk)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [DB66.lcdBack, DB66.lcdBackEdge],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.5), lineWidth: 3))
                )
                .padding(.horizontal, 20)

                // Big needle gauge.
                bigNeedleGauge
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                Button(tuner.isListening ? "STOP" : "LISTEN") { tuner.toggle() }
                    .buttonStyle(DeviceButtonStyle(
                        tint: tuner.isListening ? (DB66.startTop, DB66.startBot) : (DB66.btnTop, DB66.btnBot),
                        prominent: true))
                    .font(.title3.weight(.bold))
                    .padding(.bottom, 32)
            }

            // Surface errors / permission denial here too, since the
            // inline panel isn't visible while fullscreen is up.
            if tuner.permissionDenied || tuner.lastError != nil {
                VStack {
                    Spacer()
                    Text(tuner.permissionDenied
                         ? "Microphone access denied — enable it in Settings ▸ Privacy & Security ▸ Microphone."
                         : (tuner.lastError ?? ""))
                        .font(.callout)
                        .foregroundStyle(DB66.ledAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 84)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func readoutBlock(label: String, value: String, suffix: String,
                              valueColor: Color = DB66.lcdInk) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(DB66.lcdFont(42))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(suffix)
                    .font(DB66.lcdFont(20))
                    .foregroundStyle(DB66.lcdInk.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(DB66.lcdInk.opacity(0.55))
        }
    }

    /// Larger sibling of `TunerToneView.centsMeter`. Stroke widths and tick
    /// lengths scale with radius so the gauge stays proportionate at the
    /// fullscreen size.
    private var bigNeedleGauge: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h - 4)
            let radius = min(w / 2 - 16, h - 12)
            let arcStroke: CGFloat = max(5, radius / 30)
            let needleWidth: CGFloat = max(3, radius / 50)
            let pivotSize: CGFloat = max(14, radius / 20)
            let labelSize: CGFloat = max(14, radius / 10)

            let clamped = max(-50, min(50, tuner.cents))
            let needleAngle = Double(clamped) / 50 * 70

            ZStack {
                // Backdrop arc.
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(-160), endAngle: .degrees(-20),
                             clockwise: false)
                }
                .stroke(DB66.lcdInk.opacity(0.22),
                        style: StrokeStyle(lineWidth: arcStroke, lineCap: .round))

                // In-tune segment.
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(-97), endAngle: .degrees(-83),
                             clockwise: false)
                }
                .stroke(Color.green.opacity(0.9),
                        style: StrokeStyle(lineWidth: arcStroke + 2, lineCap: .round))

                // Tick marks.
                ForEach([-50, -25, 0, 25, 50], id: \.self) { tick in
                    bigTick(cents: tick, center: center, radius: radius,
                            length: tick == 0 ? radius / 8 : radius / 14,
                            weight: tick == 0 ? max(3, radius / 50) : max(2, radius / 80))
                }

                // Needle.
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: h - 4))
                    p.addLine(to: CGPoint(x: w / 2, y: h - radius - 4))
                }
                .stroke(inTune ? Color.green : DB66.lcdInk,
                        style: StrokeStyle(lineWidth: needleWidth, lineCap: .round))
                .rotationEffect(.degrees(tuner.hasSignal ? needleAngle : 0),
                                anchor: UnitPoint(x: 0.5, y: (h - 4) / h))
                .animation(.spring(response: 0.18, dampingFraction: 0.75),
                           value: tuner.cents)
                .opacity(tuner.hasSignal ? 1 : 0.35)

                // Pivot cap.
                Circle()
                    .fill(DB66.lcdInk)
                    .frame(width: pivotSize, height: pivotSize)
                    .position(center)

                // ♭ / ♯ labels at the swing extremes.
                Text("♭").font(DB66.lcdFont(labelSize))
                    .foregroundStyle(DB66.lcdInk.opacity(0.55))
                    .position(x: center.x - radius - 4, y: center.y - 6)
                Text("♯").font(DB66.lcdFont(labelSize))
                    .foregroundStyle(DB66.lcdInk.opacity(0.55))
                    .position(x: center.x + radius + 4, y: center.y - 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [DB66.lcdBack, DB66.lcdBackEdge],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.5), lineWidth: 3))
            )
        }
        .aspectRatio(2.2, contentMode: .fit)
    }

    private func bigTick(cents: Int, center: CGPoint, radius: CGFloat,
                         length: CGFloat, weight: CGFloat) -> some View {
        let angle = Double(cents) / 50 * 70 - 90
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
}
