// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "InputRemap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RemapCore"),
        .target(name: "RemapIO", dependencies: ["RemapCore"]),
        .executableTarget(name: "InputRemap", dependencies: ["RemapCore", "RemapIO"]),
        // Janela de teste usada só pelo E2E (foco garantido para injeção de teclado).
        .executableTarget(name: "E2EHarness"),
        // Gravador de eventos (Fase 1): só escuta, para descobrir os códigos do hardware.
        .executableTarget(name: "HardwareProbe"),
        // Guarda/restaura o espaço de cada tela em volta do E2E (scripts/e2e.sh).
        .executableTarget(name: "E2ESpaces"),
        .testTarget(name: "CoreTests", dependencies: ["RemapCore"]),
        .testTarget(name: "IOTests", dependencies: ["RemapIO"]),
        .testTarget(name: "E2ETests", dependencies: ["E2EHarness", "InputRemap"]),
    ]
)
