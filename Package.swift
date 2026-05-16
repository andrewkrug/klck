// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Klck",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Klck",
            path: "Sources/Klck"
        )
    ]
)
