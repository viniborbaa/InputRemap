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
}
