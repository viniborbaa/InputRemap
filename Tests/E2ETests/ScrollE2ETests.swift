// Rodinha do mouse invertida em relação ao trackpad, com o InputRemap rodando de verdade.
// Compara com o sentido que a janela recebe SEM o app (não depende da "rolagem natural").

import AppKit
import Testing

extension E2E {
    @Suite struct ScrollE2ETests {

        /// Sentido ("scrollUp"/"scrollDown") recebido pela janela para uma rolagem.
        func received(_ h: Harness, continuous: Bool) throws -> String {
            let before = h.clicks
            Inject.scroll(1, continuous: continuous)
            var got: String?
            try waitUntil("janela receber a rolagem") {
                got = ["scrollUp", "scrollDown"].first { h.clicks[$0, default: 0] > before[$0, default: 0] }
                return got != nil
            }
            return got!
        }

        func harnessUnderCursor() throws -> Harness {
            let h = try Harness(text: "rolagem")
            Inject.mouse(.mouseMoved, button: 0, at: h.center)
            pause(0.3)
            return h
        }

        @Test func rodinhaDoMouseFicaInvertida() throws {
            let h = try harnessUnderCursor()
            let semApp = try received(h, continuous: false)
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = app }
            #expect(try received(h, continuous: false) != semApp)
        }

        @Test func trackpadNaoMuda() throws {
            let h = try harnessUnderCursor()
            let semApp = try received(h, continuous: true)
            let app = try AppRunner(deliverTo: h.pid)
            defer { _ = app }
            #expect(try received(h, continuous: true) == semApp)
        }
    }
}
