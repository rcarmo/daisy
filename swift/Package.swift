// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "daisy-swift",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "daisy",
            path: "Sources"
        )
    ]
)
