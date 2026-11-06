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
        }
    }

    /// Atalhos de app (⌘C/⌘V) dependem do app em foco; atalhos de sistema não.
    public var isAppShortcut: Bool { flags.contains(.maskCommand) }
}

/// Envia os atalhos. Em modo de teste (`deliverTo`), atalhos de app vão direto para
/// aquele processo e nunca para o app em foco do usuário.
public struct KeyPoster {
    public var deliverTo: pid_t?

    public init(deliverTo: pid_t? = nil) { self.deliverTo = deliverTo }

    public func post(_ output: Output) {
        let k = KeyStroke(for: output)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: k.keyCode, keyDown: down) else { continue }
            e.flags = k.flags
            e.setIntegerValueField(.eventSourceUserData, value: ownEventTag)
            if let pid = deliverTo, k.isAppShortcut { e.postToPid(pid) } else { e.post(tap: .cghidEventTap) }
        }
    }
}
