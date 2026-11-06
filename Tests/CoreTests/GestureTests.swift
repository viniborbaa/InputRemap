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

    // MARK: Fase 5 — arrastar ↑ / ↓

    @Test func arrastarParaCimaAbreMissionControl() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(0, -40), (0, -40)])) == [.missionControl])
    }

    @Test func arrastarParaBaixoAbreLaunchpad() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(0, 40), (0, 40)])) == [.launchpad])
    }

    @Test func gestoDisparaDuranteOArrastoNaoAoSoltar() {
        var r = Remapper()
        let ds = gesture(&r, steps: [(0, 40), (0, 40)])
        #expect(ds[2].outputs == [.launchpad]) // [down, drag, drag(cruza limiar), up]
        #expect(ds[3].outputs.isEmpty)
    }

    @Test func gestoDisparaUmaVezSoPorPressionada() {
        var r = Remapper()
        let ds = gesture(&r, steps: [(0, -70), (0, -70), (0, 140), (0, 200)])
        #expect(allOutputs(ds) == [.missionControl])
    }

    @Test func eixoDominanteDecide() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(40, -70)])) == [.missionControl])
    }

    @Test func novoGestoDepoisDeSoltarDisparaDeNovo() {
        var r = Remapper()
        _ = gesture(&r, steps: [(0, -100)])
        #expect(allOutputs(gesture(&r, steps: [(0, 100)])) == [.launchpad])
    }

    // MARK: Fase 6 — arrastar ← / →

    @Test func arrastarParaEsquerdaVaiParaMesaDaEsquerda() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(-40, 0), (-40, 0)])) == [.spaceLeft])
    }

    @Test func arrastarParaDireitaVaiParaMesaDaDireita() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(40, 0), (40, 0)])) == [.spaceRight])
    }

    @Test func horizontalDominanteVenceVertical() {
        var r = Remapper()
        #expect(allOutputs(gesture(&r, steps: [(-70, 40)])) == [.spaceLeft])
    }
}
