// Fases 2 e 3 — botões laterais do Lift.

import Testing
@testable import RemapCore

@Suite struct MouseButtonTests {

    @Test func backPressionadoGeraCopiarEBloqueia() {
        var r = Remapper()
        #expect(r.handle(.mouseDown(button: Button.back)) == Decision(swallow: true, outputs: [.copy]))
    }

    @Test func backSoltoNaoGeraNadaMasBloqueia() {
        var r = Remapper()
        _ = r.handle(.mouseDown(button: Button.back))
        #expect(r.handle(.mouseUp(button: Button.back)) == Decision(swallow: true, outputs: []))
    }

    @Test func botoesNaoMapeadosPassamIntactos() {
        var r = Remapper()
        for b in [5, 6, 7] {
            #expect(r.handle(.mouseDown(button: b)) == .passThrough)
            #expect(r.handle(.mouseUp(button: b)) == .passThrough)
        }
    }
}
