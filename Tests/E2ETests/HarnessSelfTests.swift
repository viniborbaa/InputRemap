// Fase 0 — verifica que as ferramentas do E2E funcionam, sem o InputRemap rodando.
// Se algum destes falhar, os testes das funcionalidades não são confiáveis.

import AppKit
import Testing

extension E2E {
    @Suite struct HarnessSelfTests {

        @Test func janelaDeTesteGanhaFoco() throws {
            let h = try Harness(text: "foco")
            try h.requireFocus()
        }

        @Test func cmdCInjetadoCopiaTextoDaJanelaDeTeste() throws {
            let marker = "e2e-copy-\(UInt32.random(in: .min ... .max))"
            Clipboard.set("antes")
            let h = try Harness(text: marker)
            try h.requireFocus()
            Inject.key(8, .maskCommand) // ⌘C
            try waitUntil("clipboard receber o texto") { Clipboard.string == marker }
        }

        @Test func cmdVInjetadoColaNaJanelaDeTeste() throws {
            let marker = "e2e-paste-\(UInt32.random(in: .min ... .max))"
            Clipboard.set(marker)
            let h = try Harness(text: "substituir")
            try h.requireFocus()
            Inject.key(9, .maskCommand) // ⌘V
            try waitUntil("campo receber o texto colado") { h.content == marker }
        }

        @Test func atalhoDeMesaTrocaMesaAtiva() throws {
            let (index, count) = Spaces.activeIndex()
            try #require(count >= 2, "precisa de 2+ mesas na tela ativa")
            let original = Spaces.active()
            // Na ponta direita o ⌃→ não faz nada: vai na direção que existe.
            let (go, back): (CGKeyCode, CGKeyCode) = index < count - 1 ? (124, 123) : (123, 124)
            defer {
                if Spaces.active() != original {
                    Inject.key(back, .maskControl)
                    try? waitUntil("voltar à mesa original") { Spaces.active() == original }
                }
            }
            Inject.key(go, .maskControl)
            try waitUntil("mesa mudar") { Spaces.active() != original }
        }

        @Test func atalhoDeMissionControlAbreVisaoGeral() throws {
            defer { Overview.close() }
            #expect(!Overview.isOpen())
            Inject.key(126, .maskControl) // ⌃↑
            try waitUntil("Mission Control abrir") { Overview.isOpen() }
        }
    }
}
