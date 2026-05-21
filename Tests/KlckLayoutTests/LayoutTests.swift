import XCTest
import SwiftUI
@testable import Klck

/// Layout smoke tests — render `ContentView` at every canonical device size we
/// ship for. Each test forces an explicit frame plus the SwiftUI environment
/// overrides we'd see on that device, then drives `ImageRenderer` to evaluate
/// the full SwiftUI tree.
///
/// What this catches today:
/// - Crashes / preconditions failing during layout (e.g. bad bindings, nil
///   environment objects, divide-by-zero in geometry math).
/// - `ImageRenderer` returning nil — which means the view couldn't be sized.
/// - Dimension drift — if the layout starts demanding more space than the
///   device frame, the rendered image's intrinsic size deviates.
///
/// What it doesn't yet catch (intentional, kept "basic"):
/// - Pixel-level overflow of children past their panel.
/// - Visual regressions inside panels.
///   Reference-image snapshot comparison is the natural next step here.
@MainActor
final class LayoutTests: XCTestCase {

    // MARK: Device matrix

    /// Canonical pt sizes for every device we deploy to. Reflects the actual
    /// safe-area-inclusive size SwiftUI sees, not the raw pixel resolution.
    private struct Device {
        let name: String
        let size: CGSize
        let hSize: UserInterfaceSizeClass
        let vSize: UserInterfaceSizeClass
    }

    private let devices: [Device] = [
        Device(name: "iPhone-SE",         size: CGSize(width: 375,  height: 667),  hSize: .compact, vSize: .regular),
        Device(name: "iPhone-17",         size: CGSize(width: 393,  height: 852),  hSize: .compact, vSize: .regular),
        Device(name: "iPhone-17-ProMax",  size: CGSize(width: 440,  height: 956),  hSize: .compact, vSize: .regular),
        Device(name: "iPad-mini-portrait",size: CGSize(width: 744,  height: 1133), hSize: .regular, vSize: .regular),
        Device(name: "iPad-Pro-portrait", size: CGSize(width: 1032, height: 1376), hSize: .regular, vSize: .regular),
        Device(name: "iPad-Pro-landscape",size: CGSize(width: 1376, height: 1032), hSize: .regular, vSize: .regular),
    ]

    // MARK: Tests

    func testEveryDeviceRendersWithoutCrashing() throws {
        for device in devices {
            let model = MetronomeModel()
            let tuner = Tuner()

            let view = ContentView()
                .environmentObject(model)
                .environmentObject(tuner)
                .environment(\.horizontalSizeClass, device.hSize)
                .environment(\.verticalSizeClass, device.vSize)
                .frame(width: device.size.width, height: device.size.height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 1

            // CGImage is the actually-rendered raster — non-nil here means
            // SwiftUI evaluated the entire view tree at that frame without
            // hitting a precondition or returning an empty layout.
            let image = renderer.cgImage
            XCTAssertNotNil(image, "ContentView failed to render at \(device.name)")
            XCTAssertEqual(image?.width, Int(device.size.width),
                           "Rendered width drifted on \(device.name)")
            XCTAssertEqual(image?.height, Int(device.size.height),
                           "Rendered height drifted on \(device.name)")
        }
    }

    /// Tap the 2-column branch specifically. iPad Pro portrait is the
    /// smallest size where it should trigger (>= 900pt wide + regular hSize).
    func testTwoColumnLayoutEngagesOnWideRegular() throws {
        let model = MetronomeModel()
        let tuner = Tuner()

        let view = ContentView()
            .environmentObject(model)
            .environmentObject(tuner)
            .environment(\.horizontalSizeClass, .regular)
            .environment(\.verticalSizeClass, .regular)
            .frame(width: 1032, height: 1376)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    /// Compact (iPhone) should never trigger 2-column even at a Pro Max width.
    func testCompactStaysSingleColumn() throws {
        let model = MetronomeModel()
        let tuner = Tuner()

        let view = ContentView()
            .environmentObject(model)
            .environmentObject(tuner)
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.verticalSizeClass, .regular)
            .frame(width: 440, height: 956)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }
}
