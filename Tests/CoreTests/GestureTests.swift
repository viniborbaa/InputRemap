// Fases 4–6 — botão do meio (rodinha): clique e gestos de arrastar.

import Testing
@testable import RemapCore

@Suite struct GestureTests {

    /// Pressiona o botão do meio, arrasta em passos e devolve as decisões de cada evento.
    func gesture(_ r: inout Remapper, steps: [(Double, Double)]) -> [Decision] {
        var out = [r.handle(.mouseDown(button: Button.middle))]
        for (dx, dy) in steps { out.append(r.handle(.mouseDragged(button: Button.middle, dx: dx, dy: dy))) }
        out.append(r.handle(.mouseUp(button: Button.middle)))
        return out
    }

    func allOutputs(_ ds: [Decision]) -> [Output] { ds.flatMap(\.outputs) }

    // MARK: Fase 4 — clique simples

    @Test func cliqueSimplesAbreMissionControlAoSoltar() {
        var r = Remapper()
        #expect(r.handle(.mouseDown(button: Button.middle)) == Decision(swallow: true, outputs: []))
        #expect(r.handle(.mouseUp(button: Button.middle)) == Decision(swallow: true, outputs: [.missionControl]))
    }

    @Test func arrastoAbaixoDoLimiarContaComoClique() {
        var r = Remapper()
        let ds = gesture(&r, steps: [(10, 5), (10, -5), (-5, 10)])
        #expect(allOutputs(ds) == [.missionControl])
        #expect(ds.allSatisfy { $0.swallow })
    }

    @Test func arrastoSemBotaoDoMeioPressionadoPassaIntacto() {
        var r = Remapper()
        #expect(r.handle(.mouseDragged(button: Button.middle, dx: 100, dy: 0)) == .passThrough)
    }
}
