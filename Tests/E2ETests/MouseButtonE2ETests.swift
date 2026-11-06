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
    }
}
