// Controla a janela de teste (E2EHarness) a partir dos testes.

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

    /// Abre a janela de teste com `text` selecionado e espera ela ficar em foco.
    init(text: String) throws {
        outFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-harness-\(UUID().uuidString).txt")
        process.executableURL = builtProduct("E2EHarness")
        process.arguments = ["--text", text, "--out", outFile.path]
        try process.run()
        let pid = process.processIdentifier
        try waitUntil("janela de teste abrir", timeout: 5) {
            FileManager.default.fileExists(atPath: outFile.path)
        }
        try waitUntil("janela de teste ganhar foco de teclado", timeout: 5) { hasKeyboardFocus }
        _ = pid
    }

    /// Dupla checagem: a própria janela diz que é a janela-chave ativa (status "key")
    /// E ela é a janela mais à frente segundo o servidor de janelas.
    var hasKeyboardFocus: Bool {
        let status = (try? String(contentsOf: statusFile, encoding: .utf8)) ?? ""
        return status == "key" && frontmostPID() == process.processIdentifier
    }

    var statusFile: URL { URL(fileURLWithPath: outFile.path + ".status") }

    /// Garante que a janela de teste recebe o teclado. Chamar antes de toda injeção de teclado.
    func requireFocus() throws {
        guard hasKeyboardFocus else {
            throw E2EError.focusLost(expected: process.processIdentifier, actual: frontmostPID())
        }
    }

    var content: String { (try? String(contentsOf: outFile, encoding: .utf8)) ?? "" }

    deinit {
        process.terminate()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: outFile)
        try? FileManager.default.removeItem(at: statusFile)
    }
}
