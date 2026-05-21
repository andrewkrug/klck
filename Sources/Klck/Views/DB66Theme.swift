import SwiftUI

/// Visual language modeled on the Boss Dr. Beat DB-66: dark plastic chassis,
/// a backlit pale-green LCD with dark "ink", and beveled rubber buttons.
enum DB66 {
    // Chassis
    static let chassisTop  = Color(red: 0.20, green: 0.21, blue: 0.22)
    static let chassisBot  = Color(red: 0.10, green: 0.105, blue: 0.11)
    static let panel       = Color(red: 0.16, green: 0.165, blue: 0.175)
    static let panelEdge   = Color.white.opacity(0.06)
    static let engrave     = Color(red: 0.62, green: 0.64, blue: 0.66)

    // LCD
    static let lcdBack     = Color(red: 0.66, green: 0.73, blue: 0.55)
    static let lcdBackEdge = Color(red: 0.56, green: 0.63, blue: 0.46)
    static let lcdInk      = Color(red: 0.09, green: 0.13, blue: 0.07)
    static let lcdInkDim   = Color(red: 0.09, green: 0.13, blue: 0.07).opacity(0.22)

    // LEDs
    static let ledAccent   = Color(red: 1.0, green: 0.27, blue: 0.20)   // red
    static let ledBeat     = Color(red: 1.0, green: 0.74, blue: 0.18)   // amber
    static let ledOff      = Color.white.opacity(0.10)

    // Buttons
    static let btnTop      = Color(red: 0.27, green: 0.28, blue: 0.30)
    static let btnBot      = Color(red: 0.17, green: 0.175, blue: 0.19)
    static let startTop    = Color(red: 0.93, green: 0.30, blue: 0.24)
    static let startBot    = Color(red: 0.74, green: 0.18, blue: 0.14)

    static let chassis = LinearGradient(
        colors: [chassisTop, chassisBot],
        startPoint: .top, endPoint: .bottom
    )

    /// Monospaced, heavy — stands in for a 7-segment LCD readout.
    static func lcdFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}

/// A recessed control panel on the chassis. Inner padding tightens to 12 on
/// iPhone so the panel content gets back ~8pt of horizontal room (every
/// pixel matters at iPhone-SE width).
struct DevicePanel: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        let inset: CGFloat = hSize == .compact ? 12 : 16
        return content
            .padding(inset)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DB66.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(DB66.panelEdge, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
            )
    }
}

extension View {
    func devicePanel() -> some View { modifier(DevicePanel()) }
}

/// Beveled rubber button.
struct DeviceButtonStyle: ButtonStyle {
    @Environment(\.horizontalSizeClass) private var hSize
    var tint: (Color, Color) = (DB66.btnTop, DB66.btnBot)
    var prominent = false

    private var isCompact: Bool { hSize == .compact }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 12 : 13, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : DB66.engrave)
            .padding(.vertical, isCompact ? 8 : 10)
            .padding(.horizontal, isCompact ? 8 : 14)
            .frame(minWidth: isCompact ? 44 : 56)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tint.0, tint.1],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
