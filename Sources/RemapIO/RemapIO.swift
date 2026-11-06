// Adaptadores entre CGEvent e o RemapCore.

import CoreGraphics
import RemapCore

/// Marca dos eventos gerados pelo próprio InputRemap (para não reprocessá-los).
public let ownEventTag: Int64 = 0x1A9E7

public enum EventTranslator {
    /// Converte um CGEvent em entrada do núcleo. `nil` = não interessa (inclui eventos
    /// gerados pelo próprio app).
    public static func input(from event: CGEvent) -> Input? {
        if event.getIntegerValueField(.eventSourceUserData) == ownEventTag { return nil }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        switch event.type {
        case .otherMouseDown: return .mouseDown(button: button)
        case .otherMouseUp: return .mouseUp(button: button)
        case .otherMouseDragged:
            return .mouseDragged(button: button,
                                 dx: Double(event.getIntegerValueField(.mouseEventDeltaX)),
                                 dy: Double(event.getIntegerValueField(.mouseEventDeltaY)))
        default: return nil
        }
    }
}

public struct KeyStroke: Equatable {
    public var keyCode: CGKeyCode
    public var flags: CGEventFlags

    public init(keyCode: CGKeyCode, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.flags = flags
    }

    public init(for output: Output) {
        switch output {
        case .copy: self.init(keyCode: 8, flags: .maskCommand)
        case .paste: self.init(keyCode: 9, flags: .maskCommand)
        case .missionControl: self.init(keyCode: 126, flags: Self.arrow)
        case .appExpose: self.init(keyCode: 125, flags: Self.arrow)
        case .spaceLeft: self.init(keyCode: 123, flags: Self.arrow)
        case .spaceRight: self.init(keyCode: 124, flags: Self.arrow)
        }
    }

    /// ⌃ + seta (atalhos de mesa/Mission Control); setas precisam de fn + teclado numérico.
    static let arrow: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]

    /// Atalhos de app (⌘C/⌘V) dependem do app em foco; atalhos de sistema não.
    public var isAppShortcut: Bool { flags.contains(.maskCommand) }
}

/// Envia os atalhos. Em modo de teste (`deliverTo`), atalhos de app vão direto para
/// aquele processo e nunca para o app em foco do usuário.
public struct KeyPoster {
    public var deliverTo: pid_t?

    public init(deliverTo: pid_t? = nil) { self.deliverTo = deliverTo }

    /// Eventos de tecla (pressionar e soltar) do atalho, marcados como gerados pelo app.
    public static func makeEvents(for output: Output) -> [CGEvent] {
        let k = KeyStroke(for: output)
        return [true, false].compactMap { down in
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: k.keyCode, keyDown: down) else { return nil }
            e.flags = k.flags
            e.setIntegerValueField(.eventSourceUserData, value: ownEventTag)
            return e
        }
    }

    public func post(_ output: Output) {
        let appShortcut = KeyStroke(for: output).isAppShortcut
        for e in Self.makeEvents(for: output) {
            if let pid = deliverTo, appShortcut { e.postToPid(pid) } else { e.post(tap: .cghidEventTap) }
        }
    }
}
