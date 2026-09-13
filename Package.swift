// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LunalithCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LunalithCore", targets: ["LunalithCore"])
    ],
    targets: [
        .target(name: "LunalithCore"),
        .testTarget(name: "LunalithCoreTests", dependencies: ["LunalithCore"])
    ]
)
