// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YiRiYiJian",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "YiRiYiJian", targets: ["YiRiYiJian"]),
        .executable(name: "SelfTest", targets: ["SelfTest"]),
        .executable(name: "RenderShots", targets: ["RenderShots"])
    ],
    targets: [
        .target(name: "Core", path: "Sources/Core"),
        .target(name: "UI", dependencies: ["Core"], path: "Sources/UI"),
        .executableTarget(name: "YiRiYiJian", dependencies: ["Core", "UI"], path: "Sources/YiRiYiJian"),
        .executableTarget(name: "SelfTest", dependencies: ["Core", "UI"], path: "Sources/SelfTest"),
        .executableTarget(name: "RenderShots", dependencies: ["Core", "UI"], path: "Sources/RenderShots")
    ]
)
