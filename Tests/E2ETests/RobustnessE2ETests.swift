// Fase 8 — robustez, com o InputRemap rodando de verdade.

import AppKit
import Testing

extension E2E {
    @Suite struct RobustnessE2ETests {

        @Test func cliquesEsquerdoEDireitoPassamIntactos() throws {
            let h = try Harness(text: "cliques")
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = (h, app) }
            Inject.click(.leftMouseDown, .leftMouseUp, at: h.center)
            Inject.click(.rightMouseDown, .rightMouseUp, at: h.center)
            try waitUntil("janela receber os dois cliques") { h.clicks["left"] == 1 && h.clicks["right"] == 1 }
        }

        @Test func botoesNaoMapeadosPassamIntactos() throws {
            let h = try Harness(text: "botões")
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = (h, app) }
            Inject.mouse(.otherMouseDown, button: 5, at: h.center)
            Inject.mouse(.otherMouseUp, button: 5, at: h.center)
            try waitUntil("janela receber o botão 5") { h.clicks["other5"] == 1 }
        }

        @Test func botoesMapeadosNaoChegamNaJanela() throws {
            let h = try Harness(text: "mapeados")
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = (h, app) }
            for b: Int64 in [3, 4] {
                Inject.mouse(.otherMouseDown, button: b, at: h.center)
                Inject.mouse(.otherMouseUp, button: b, at: h.center)
            }
            Inject.click(.leftMouseDown, .leftMouseUp, at: h.center) // marcador de "eventos processados"
            try waitUntil("clique esquerdo chegar") { h.clicks["left"] == 1 }
            #expect(h.clicks["other3"] == nil && h.clicks["other4"] == nil)
        }

        @Test func digitacaoPassaIntacta() throws {
            let h = try Harness(text: "abc")
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = (h, app) }
            Inject.key(0, to: h.pid) // "a"
            try waitUntil("campo virar 'a'") { h.content == "a" }
        }

        /// Faz o app demorar (trava 3 s no botão 6) até o macOS desligar o tap por demora.
        /// O app tem que religá-lo sozinho e o Back voltar a copiar.
        /// (SIGSTOP não serve: com o processo congelado o macOS espera para sempre.)
        @Test(.disabled("incidente 4: deixou visão geral travada; investigar com logs antes de reativar"))
        func religaInterceptacaoDepoisDeDesligadaPorDemora() throws {
            let marker = "e2e-religa-\(UInt32.random(in: .min ... .max))"
            Clipboard.set("antes")
            let h = try Harness(text: marker)
            let app = try AppRunner(deliverTo: h.pid, hangButton: 6)
            defer { _ = (h, app) }

            Inject.mouse(.otherMouseDown, button: 6, at: h.center)
            Inject.mouse(.otherMouseUp, button: 6, at: h.center)
            pause(4) // app travado 3 s → macOS desliga o tap; app volta e recebe o aviso

            Inject.mouse(.otherMouseDown, button: 3, at: h.center)
            Inject.mouse(.otherMouseUp, button: 3, at: h.center)
            try waitUntil("Back copiar depois de religado") { Clipboard.string == marker }
        }
    }
}
