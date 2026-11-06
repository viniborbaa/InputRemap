// Controla a janela de teste (E2EHarness) a partir dos testes.
//
// Teclas para a janela de teste são entregues com postToPid (Inject.key(_:to:)):
// a ordem das janelas e o status de janela-chave NÃO garantem para onde o macOS
// manda teclas postadas globalmente (ver incidente 2 no PLAN.md).

import AppKit
import Foundation

/// Raiz do pacote, derivada da localização deste arquivo.
let packageRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

func builtProduct(_ name: String) -> URL {
    packageRoot.appendingPathComponent(".build/debug/\(name)")
}

final class Harness {
    let process = Process()
    let outFile: URL
    var pid: pid_t { process.processIdentifier }

    /// Abre a janela de teste com `text` selecionado e espera ela ficar pronta.
    init(text: String) throws {
        outFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-harness-\(UUID().uuidString).txt")
        process.executableURL = builtProduct("E2EHarness")
        process.arguments = ["--text", text, "--out", outFile.path]
        try process.run()
        try waitUntil("janela de teste abrir", timeout: 5) {
            FileManager.default.fileExists(atPath: outFile.path)
        }
        pause(0.3) // deixa o campo de texto assumir o cursor
    }

    var content: String { (try? String(contentsOf: outFile, encoding: .utf8)) ?? "" }

    deinit {
        process.terminate()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: outFile)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: outFile.path + ".status"))
    }
}
