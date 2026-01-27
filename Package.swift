// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpeechKit",
    platforms: [
        .visionOS(.v2),
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpeechKit",
            targets: ["SpeechKit"]
        ),
    ],
    targets: [
        .target(
            name: "SpeechKit"
        ),
        .testTarget(
            name: "SpeechKitTests",
            dependencies: ["SpeechKit"]
        ),
    ]
)
