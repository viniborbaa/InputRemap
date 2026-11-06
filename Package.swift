// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "InputRemap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RemapCore"),
        .target(name: "RemapIO", dependencies: ["RemapCore"]),
        .executableTarget(name: "InputRemap", dependencies: ["RemapCore", "RemapIO"]),
        .testTarget(name: "CoreTests", dependencies: ["RemapCore"]),
        .testTarget(name: "IOTests", dependencies: ["RemapIO"]),
        .testTarget(name: "E2ETests", dependencies: []),
    ]

)
