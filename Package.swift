// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OpenFocus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OpenFocus",
            path: "Sources/OpenFocus"
        )
    ]
)
