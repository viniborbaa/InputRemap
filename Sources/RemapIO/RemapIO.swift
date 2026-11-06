// Adaptadores entre CGEvent e o RemapCore.

import CoreGraphics
import CoreServices
import Foundation
import RemapCore

/// Marca dos eventos gerados pelo próprio InputRemap (para não reprocessá-los).
public let ownEventTag: Int64 = 0x1A9E7

/// Marca dos eventos injetados pelos testes E2E (mesmo valor usado em Tests/E2ETests).
public let testEventTag: Int64 = 0x7E57

public enum EventTranslator {
    /// Converte um CGEvent em entrada do núcleo. `nil` = não interessa (inclui eventos
    /// gerados pelo próprio app e, com `ignoringTestEvents`, os injetados pelo E2E).
    public static func input(from event: CGEvent, ignoringTestEvents: Bool = false) -> Input? {
        let tag = event.getIntegerValueField(.eventSourceUserData)
        if tag == ownEventTag || (ignoringTestEvents && tag == testEventTag) { return nil }
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

    /// `nil` = a saída não é uma tecla (ex.: Launchpad, que abre um app).
    public init?(for output: Output) {
        switch output {
        case .copy: self.init(keyCode: 8, flags: .maskCommand)
        case .paste: self.init(keyCode: 9, flags: .maskCommand)
        case .missionControl: self.init(keyCode: 126, flags: Self.arrow)
        case .launchpad: return nil
        case .spaceLeft: self.init(keyCode: 123, flags: Self.arrow)
        case .spaceRight: self.init(keyCode: 124, flags: Self.arrow)
        }
    }

    /// ⌃ + seta (atalhos de mesa/Mission Control); setas precisam de fn + teclado numérico.
    static let arrow: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]

    /// Atalhos de app (⌘C/⌘V) dependem do app em foco; atalhos de sistema não.
    public var isAppShortcut: Bool { flags.contains(.maskCommand) }
}

/// Saídas que abrem um app em vez de mandar uma tecla.
public enum Launcher {
    public static func app(for output: Output) -> URL? {
        output == .launchpad ? URL(fileURLWithPath: "/System/Applications/Launchpad.app") : nil
    }
}

/// Envia os atalhos. Em modo de teste (`deliverTo`), atalhos de app vão direto para
/// aquele processo e nunca para o app em foco do usuário.
public struct KeyPoster {
    public var deliverTo: pid_t?

    public init(deliverTo: pid_t? = nil) { self.deliverTo = deliverTo }

    /// Eventos de tecla (pressionar e soltar) do atalho, marcados como gerados pelo app.
    public static func makeEvents(for output: Output) -> [CGEvent] {
        guard let k = KeyStroke(for: output) else { return [] }
        return [true, false].compactMap { down in
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: k.keyCode, keyDown: down) else { return nil }
            e.flags = k.flags
            e.setIntegerValueField(.eventSourceUserData, value: ownEventTag)
            return e
        }
    }

    public func post(_ output: Output) {
        if let url = Launcher.app(for: output) {
            LSOpenCFURLRef(url as CFURL, nil)
            return
        }
        let appShortcut = KeyStroke(for: output)?.isAppShortcut ?? false
        for e in Self.makeEvents(for: output) {
            if let pid = deliverTo, appShortcut { e.postToPid(pid) } else { e.post(tap: .cghidEventTap) }
        }
    }
}

/// Inverte a rodinha do mouse (ver `ScrollPolicy`).
public enum ScrollInverter {
    public static func shouldInvert(_ e: CGEvent, ignoringTestEvents: Bool) -> Bool {
        let tag = e.getIntegerValueField(.eventSourceUserData)
        if tag == ownEventTag || (ignoringTestEvents && tag == testEventTag) { return false }
        return ScrollPolicy.shouldInvert(continuous: e.getIntegerValueField(.scrollWheelEventIsContinuous) != 0)
    }

    /// Nega os deltas do eixo vertical (linhas, pontos e ponto fixo); o horizontal fica igual.
    public static func invertVertical(_ e: CGEvent) {
        // Lê tudo antes: escrever um campo faz o CoreGraphics recalcular os outros.
        let delta = e.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let point = e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let fixed = e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        e.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed)
        e.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point)
    }
}
