// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LunalithCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LunalithCore", targets: ["LunalithCore"]),
        .library(name: "LunalithHarness", targets: ["LunalithHarness"]),
        .executable(name: "lunalith-context", targets: ["LunalithContextTool"])
    ],
    targets: [
        .target(name: "LunalithCore"),
        .target(name: "LunalithHarness", dependencies: ["LunalithCore"]),
        .executableTarget(name: "LunalithContextTool", dependencies: ["LunalithCore", "LunalithHarness"]),
        .testTarget(name: "LunalithCoreTests", dependencies: ["LunalithCore", "LunalithHarness"])
    ]
)
