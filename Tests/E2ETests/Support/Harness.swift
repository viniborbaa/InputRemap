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
    /// `center`: posição da janela em coordenadas globais (ex.: numa tela com 2+ mesas).
    init(text: String, center: CGPoint? = nil) throws {
        outFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-harness-\(UUID().uuidString).txt")
        process.executableURL = builtProduct("E2EHarness")
        process.arguments = ["--text", text, "--out", outFile.path]
            + (center.map { ["--center", "\($0.x)", "\($0.y)"] } ?? [])
        try process.run()
        try waitUntil("janela de teste abrir", timeout: 5) {
            FileManager.default.fileExists(atPath: outFile.path)
        }
        // Pronta = a própria janela diz que é a janela-chave ativa. Não é garantia de
        // foco para teclas globais (incidente 2), mas é pré-requisito para ⌘C/⌘V via pid.
        try waitUntil("janela de teste ficar ativa", timeout: 5) {
            (try? String(contentsOf: URL(fileURLWithPath: outFile.path + ".status"), encoding: .utf8)) == "key"
        }
        pause(0.2)
    }

    /// Centro da janela de teste em coordenadas globais (origem no canto superior esquerdo).
    /// Eventos de mouse vão para a janela sob o cursor: injetar aqui garante que, se o
    /// InputRemap não bloquear o clique, ele cai na janela de teste e não no app do usuário.
    var center: CGPoint {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let w = list.first { ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) &&
                             ($0[kCGWindowLayer as String] as? Int) == 0 }
        var r = CGRect.zero
        if let b = w?[kCGWindowBounds as String] { CGRectMakeWithDictionaryRepresentation(b as! CFDictionary, &r) }
        return CGPoint(x: r.midX, y: r.midY)
    }

    var content: String { (try? String(contentsOf: outFile, encoding: .utf8)) ?? "" }

    deinit {
        process.terminate()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: outFile)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: outFile.path + ".status"))
    }
}
