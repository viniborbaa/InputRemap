// Tradução CGEvent ↔ RemapCore.

import CoreGraphics
import Testing
import RemapCore
@testable import RemapIO

@Suite struct TranslationTests {

    func mouse(_ t: CGEventType, button: Int64, tag: Int64 = 0) -> CGEvent {
        let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: .zero,
                        mouseButton: CGMouseButton(rawValue: UInt32(button))!)!
        e.setIntegerValueField(.mouseEventButtonNumber, value: button)
        e.setIntegerValueField(.eventSourceUserData, value: tag)
        return e
    }

    @Test func otherMouseDownViraMouseDown() {
        #expect(EventTranslator.input(from: mouse(.otherMouseDown, button: 3)) == .mouseDown(button: 3))
    }

    @Test func otherMouseUpViraMouseUp() {
        #expect(EventTranslator.input(from: mouse(.otherMouseUp, button: 4)) == .mouseUp(button: 4))
    }

    @Test func otherMouseDraggedViraMouseDraggedComDeltas() {
        let e = mouse(.otherMouseDragged, button: 2)
        e.setIntegerValueField(.mouseEventDeltaX, value: 7)
        e.setIntegerValueField(.mouseEventDeltaY, value: -3)
        #expect(EventTranslator.input(from: e) == .mouseDragged(button: 2, dx: 7, dy: -3))
    }

    @Test func eventosGeradosPeloProprioAppSaoIgnorados() {
        #expect(EventTranslator.input(from: mouse(.otherMouseDown, button: 3, tag: ownEventTag)) == nil)
    }

    /// O app instalado (LaunchAgent) não pode reagir aos eventos injetados pelo E2E:
    /// senão mandaria ⌘C/⌘V para o app em foco do usuário enquanto os testes rodam.
    @Test func modoInstaladoIgnoraEventosDoE2E() {
        #expect(EventTranslator.input(from: mouse(.otherMouseDown, button: 3, tag: testEventTag),
                                      ignoringTestEvents: true) == nil)
    }

    @Test func modoDeTesteProcessaEventosDoE2E() {
        #expect(EventTranslator.input(from: mouse(.otherMouseDown, button: 3, tag: testEventTag),
                                      ignoringTestEvents: false) == .mouseDown(button: 3))
    }

    @Test func copiarEhCmdC() {
        #expect(KeyStroke(for: .copy) == KeyStroke(keyCode: 8, flags: .maskCommand))
    }

    @Test func colarEhCmdV() {
        #expect(KeyStroke(for: .paste) == KeyStroke(keyCode: 9, flags: .maskCommand))
    }

    static let arrow: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]

    @Test func missionControlEhCtrlSetaParaCima() {
        #expect(KeyStroke(for: .missionControl) == KeyStroke(keyCode: 126, flags: Self.arrow))
        #expect(!KeyStroke(for: .missionControl).isAppShortcut)
    }

    @Test func appExposeEhCtrlSetaParaBaixo() {
        #expect(KeyStroke(for: .appExpose) == KeyStroke(keyCode: 125, flags: Self.arrow))
    }

    @Test func mesasSaoCtrlSetasLaterais() {
        #expect(KeyStroke(for: .spaceLeft) == KeyStroke(keyCode: 123, flags: Self.arrow))
        #expect(KeyStroke(for: .spaceRight) == KeyStroke(keyCode: 124, flags: Self.arrow))
    }

    @Test func atalhosGeradosPeloAppSaoMarcadosEIgnorados() {
        let posted = KeyPoster.makeEvents(for: .copy)
        #expect(posted.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == ownEventTag })
        #expect(posted.allSatisfy { EventTranslator.input(from: $0) == nil })
    }

    @Test func eventosDeTecladoNaoInteressamAoNucleo() {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        #expect(EventTranslator.input(from: e) == nil)
    }
}
