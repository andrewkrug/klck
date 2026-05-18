// swift-tools-version:5.9
import PackageDescription

// The macOS app builds straight from SwiftPM (`./build_app.sh`, no Xcode).
// The iOS app shares these exact sources but is built through an Xcode
// project generated from `project.yml` (see README → "iOS").
let package = Package(
    name: "Klck",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    targets: [
        .executableTarget(
            name: "Klck",
            path: "Sources/Klck"
        )
    ]
)
