// Rodinha do mouse ao contrário do trackpad (o Options+ fazia isso).
// "Rolagem natural" do macOS vale para os dois; o app inverte só a rodinha do mouse.

import Testing
import RemapCore

@Suite struct ScrollTests {
    @Test func rodinhaDoMouseEhInvertida() {
        #expect(ScrollPolicy.shouldInvert(continuous: false))
    }

    /// Trackpad (e mouses com rolagem suave) mandam rolagem contínua: fica como está.
    @Test func rolagemContinuaDoTrackpadNaoEhInvertida() {
        #expect(!ScrollPolicy.shouldInvert(continuous: true))
    }
}
