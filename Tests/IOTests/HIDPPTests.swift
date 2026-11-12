// Protocolo HID++ da Logitech: tecla da calculadora do MX Keys S.

import Testing
import RemapCore
@testable import RemapIO

@Suite struct HIDPPTests {

    func report(_ bytes: [UInt8]) -> [UInt8] { bytes + [UInt8](repeating: 0, count: 20 - bytes.count) }

    /// Pergunta ao teclado o índice da feature 0x1B04 (teclas reprogramáveis).
    @Test func pedidoDoIndiceDaFeature() {
        #expect(HIDPP.getFeature(0x1B04) == report([0x11, 0xFF, 0x00, 0x0A, 0x1B, 0x04]))
    }

    /// Desvia a tecla para o app (divert + dvalid), em vez de o teclado tratá-la sozinho.
    @Test func pedidoParaDesviarATecla() {
        #expect(HIDPP.divert(cid: 0x000A, featureIndex: 9) == report([0x11, 0xFF, 0x09, 0x3A, 0x00, 0x0A, 0x03]))
    }

    @Test func respostaComOIndiceDaFeature() {
        let r = report([0x11, 0xFF, 0x00, 0x0A, 0x09, 0x00, 0x05])
        #expect(HIDPP.parse(r, reprogIndex: nil) == .featureIndex(9))
    }

    /// Bytes capturados do MX Keys S real: aperta (CID 0x000A) e solta (lista vazia).
    @Test func avisosDeTeclaDesviada() {
        #expect(HIDPP.parse(report([0x11, 0xFF, 0x09, 0x00, 0x00, 0x0A]), reprogIndex: 9) == .pressed([0x000A]))
        #expect(HIDPP.parse(report([0x11, 0xFF, 0x09, 0x00]), reprogIndex: 9) == .pressed([]))
    }

    @Test func outrosRelatoriosSaoIgnorados() {
        #expect(HIDPP.parse(report([0x11, 0xFF, 0x09, 0x00, 0x00, 0x0A]), reprogIndex: nil) == nil)
        #expect(HIDPP.parse(report([0x11, 0xFF, 0x09, 0x3A, 0x00, 0x0A, 0x03]), reprogIndex: 9) == nil)
        #expect(HIDPP.parse(report([0x11, 0xFF, 0xFF, 0x00, 0x0A]), reprogIndex: 9) == nil)
        #expect(HIDPP.parse([0x05, 0x00, 0x04], reprogIndex: 9) == nil)
    }

    /// Dispara uma vez por aperto: segurar a tecla não repete.
    @Test func calculadoraAbreUmaVezPorAperto() {
        var key = DivertedKey(cid: HIDPP.calculatorCID)
        #expect(key.update([0x000A]) == true)
        #expect(key.update([0x000A]) == false)
        #expect(key.update([]) == false)
        #expect(key.update([0x00C7, 0x000A]) == true)
    }

    @Test func calculadoraAbreOApp() {
        #expect(KeyStroke(for: .calculator) == nil)
        #expect(Launcher.app(for: .calculator)?.path == "/System/Applications/Calculator.app")
    }
}
