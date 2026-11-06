// Fases 2 e 3 — botões laterais do Lift, com o InputRemap rodando de verdade.

import AppKit
import Testing

extension E2E {
    @Suite struct MouseButtonE2ETests {

        @Test func backCopiaTextoSelecionado() throws {
            let marker = "e2e-back-\(UInt32.random(in: .min ... .max))"
            Clipboard.set("antes")
            let h = try Harness(text: marker)
            let app = try AppRunner(deliverTo: h.pid)
            Inject.mouse(.otherMouseDown, button: 3, at: h.center)
            Inject.mouse(.otherMouseUp, button: 3, at: h.center)
            try waitUntil("clipboard receber o texto") { Clipboard.string == marker }
            _ = app
        }

        @Test func forwardColaNoCampo() throws {
            let marker = "e2e-forward-\(UInt32.random(in: .min ... .max))"
            Clipboard.set(marker)
            let h = try Harness(text: "substituir")
            let app = try AppRunner(deliverTo: h.pid)
            Inject.mouse(.otherMouseDown, button: 4, at: h.center)
            Inject.mouse(.otherMouseUp, button: 4, at: h.center)
            try waitUntil("campo receber o texto colado") { h.content == marker }
            _ = app
        }
    
        // MARK: Fase 4

        @Test func cliqueDaRodinhaAbreMissionControl() throws {
            try #require(!Overview.isOpen())
            let h = try Harness(text: "rodinha")
            let app = try AppRunner(deliverTo: h.pid)
            // Fecha ANTES de encerrar janela de teste e app (referenciá-los aqui os mantém vivos).
            defer { Overview.close(toggle: 126); _ = (h, app) }
            Inject.mouse(.otherMouseDown, button: 2, at: h.center)
            Inject.mouse(.otherMouseUp, button: 2, at: h.center)
            try waitUntil("Mission Control abrir") { Overview.isOpen() }
        }

        // MARK: Fase 5

        func dragOpensOverview(dy: Int64, toggle: CGKeyCode) throws {
            try #require(!Overview.isOpen())
            let h = try Harness(text: "gesto")
            let app = try AppRunner(deliverTo: h.pid)
            defer { Overview.close(toggle: toggle); _ = (h, app) }
            // Segura o botão e arrasta SEM soltar: o gesto tem que disparar durante o
            // arrasto (soltar sem gesto seria um clique, que também abre o Mission Control).
            Inject.mouse(.otherMouseDown, button: 2, at: h.center)
            defer { Inject.mouse(.otherMouseUp, button: 2, at: h.center) }
            for _ in 0..<10 {
                Inject.mouse(.otherMouseDragged, button: 2, at: h.center, delta: (0, dy / 10))
                pause(0.01)
            }
            try waitUntil("visão geral abrir com o botão ainda pressionado") { Overview.isOpen() }
        }

        @Test func arrastarParaCimaAbreMissionControl() throws { try dragOpensOverview(dy: -150, toggle: 126) }
        @Test func arrastarParaBaixoAbreAppExpose() throws { try dragOpensOverview(dy: 150, toggle: 125) }
    
        // MARK: Fase 6

        /// Arrasta na horizontal numa tela com 2+ mesas comuns e confere que a mesa ativa
        /// virou a vizinha NA DIREÇÃO do arrasto. Sempre restaura a mesa original.
        @Test func arrastarNaHorizontalTrocaParaMesaVizinha() throws {
            try #require(!Overview.isOpen())
            let target = try #require(Spaces.displayWithMultipleSpaces(), "precisa de uma tela com 2+ mesas comuns")
            let h = try Harness(text: "mesa", center: CGPoint(x: target.bounds.midX, y: target.bounds.midY))
            let app = try AppRunner(deliverTo: h.pid)
            Inject.mouse(.mouseMoved, button: 0, at: h.center)
            pause(0.2)
            let start = Spaces.cursorDisplay()
            let goRight = start.index < start.spaces.count - 1
            let expected = start.spaces[start.index + (goRight ? 1 : -1)]
            defer {
                // Se o gesto falhar, soltar vira clique → Mission Control; fecha.
                Overview.close(toggle: 126)
                if Spaces.cursorDisplay().current != start.current {
                    Inject.systemKey(goRight ? 123 : 124, .maskControl)
                    try? waitUntil("voltar à mesa original") { Spaces.cursorDisplay().current == start.current }
                }
                _ = (h, app)
            }
            Inject.drag(button: 2, dx: goRight ? 150 : -150, dy: 0)
            try waitUntil("ir para a mesa \(goRight ? "da direita" : "da esquerda")") {
                Spaces.cursorDisplay().current == expected
            }
        }
    }
}
