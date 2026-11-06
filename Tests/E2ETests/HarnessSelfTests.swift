// Fase 0 — verifica que as ferramentas do E2E funcionam, sem o InputRemap rodando.
// Se algum destes falhar, os testes das funcionalidades não são confiáveis.

import AppKit
import Testing

extension E2E {
    @Suite struct HarnessSelfTests {

        @Test func teclaEntreguePorPidChegaNaJanelaDeTeste() throws {
            let h = try Harness(text: "abc")
            Inject.key(0, to: h.pid) // "a" substitui a seleção
            try waitUntil("campo virar 'a'") { h.content == "a" }
        }

        @Test func cmdCPorPidCopiaTextoDaJanelaDeTeste() throws {
            let marker = "e2e-copy-\(UInt32.random(in: .min ... .max))"
            Clipboard.set("antes")
            let h = try Harness(text: marker)
            Inject.key(8, .maskCommand, to: h.pid) // ⌘C
            try waitUntil("clipboard receber o texto") { Clipboard.string == marker }
        }

        @Test func cmdVPorPidColaNaJanelaDeTeste() throws {
            let marker = "e2e-paste-\(UInt32.random(in: .min ... .max))"
            Clipboard.set(marker)
            let h = try Harness(text: "substituir")
            Inject.key(9, .maskCommand, to: h.pid) // ⌘V
            try waitUntil("campo receber o texto colado") { h.content == marker }
        }

        @Test func atalhoDeMesaTrocaMesaDaTelaDoCursor() throws {
            try #require(!Overview.isOpen())
            let target = try #require(Spaces.displayWithMultipleSpaces(), "precisa de uma tela com 2+ mesas comuns (não tela cheia)")
            // Leva o cursor para essa tela, sobre uma janela de teste (movimento inofensivo).
            let h = try Harness(text: "mesa", center: CGPoint(x: target.bounds.midX, y: target.bounds.midY))
            defer { _ = h }
            Inject.mouse(.mouseMoved, button: 0, at: h.center)
            pause(0.2)
            let start = Spaces.cursorDisplay()
            try #require(start.spaces.count >= 2, "precisa de 2+ mesas na tela do cursor")
            // Na ponta direita o ⌃→ não faz nada: vai na direção que existe.
            let (go, back): (CGKeyCode, CGKeyCode) =
                start.index < start.spaces.count - 1 ? (124, 123) : (123, 124)
            defer {
                if Spaces.cursorDisplay().current != start.current {
                    Inject.systemKey(back, .maskControl)
                    try? waitUntil("voltar à mesa original") { Spaces.cursorDisplay().current == start.current }
                }
            }
            Inject.systemKey(go, .maskControl)
            try waitUntil("mesa mudar") { Spaces.cursorDisplay().current != start.current }
        }

        @Test func atalhoDeMissionControlAbreVisaoGeral() throws {
            try #require(!Overview.isOpen())
            defer { Overview.close(toggle: 126) }
            Inject.systemKey(126, .maskControl) // ⌃↑
            try waitUntil("Mission Control abrir") { Overview.isOpen() }
        }
    }
}
