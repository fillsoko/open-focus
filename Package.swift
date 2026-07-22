// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotchMVP",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotchMVP",
            path: "Sources/NotchMVP"
        )
    ]
)
