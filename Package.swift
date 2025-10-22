// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "drawing_pad",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DrawingPad",
            targets: ["drawing_pad"]
        )
    ],
    targets: [
        .executableTarget(
            name: "drawing_pad"
        )
    ]
)
