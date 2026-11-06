// Utilitários do E2E: injeção de eventos, foco, mesas (Spaces), visão geral e clipboard.

import AppKit
import ApplicationServices

let e2eEnabled = ProcessInfo.processInfo.environment["E2E"] == "1"

/// Marca dos eventos injetados pelos testes (o app usa outra marca para os próprios atalhos).
let testEventTag: Int64 = 0x7E57

enum E2EError: Error, CustomStringConvertible {
    case timeout(String)
    case notFound(String)

    var description: String {
        switch self {
        case let .timeout(s): return "tempo esgotado: \(s)"
        case let .notFound(s): return "não encontrado: \(s)"
        }
    }
}

/// Espera até `cond` ser verdadeiro, checando a cada 50 ms.
func waitUntil(_ what: String, timeout: TimeInterval = 3, _ cond: () -> Bool) throws {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end {
        if cond() { return }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    throw E2EError.timeout(what)
}

func pause(_ s: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

// MARK: - Injeção

enum Inject {
    static let arrowFlags: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]

    /// Teclas que podem ir para o sistema todo: setas (com ⌃ = atalhos de mesa/Mission
    /// Control, tratados pelo macOS) e Esc. Qualquer outra tecla global poderia cair
    /// no app em foco do usuário — proibido (ver incidentes no PLAN.md).
    static let globalAllowed: Set<CGKeyCode> = [53, 123, 124, 125, 126]

    /// Atalho de sistema, postado globalmente. Só setas e Esc.
    static func systemKey(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
        precondition(globalAllowed.contains(code), "tecla \(code) não pode ser postada globalmente")
        var f = flags
        if (123...126).contains(code) { f.formUnion(arrowFlags) }
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
            e.flags = f
            e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
            e.post(tap: .cghidEventTap)
        }
    }

    /// Tecla entregue direto a um processo: nunca chega a outro app.
    static func key(_ code: CGKeyCode, _ flags: CGEventFlags = [], to pid: pid_t) {
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
            e.postToPid(pid)
        }
    }

    static var cursor: CGPoint { CGEvent(source: nil)!.location }

    static func mouse(_ type: CGEventType, button: Int64, at p: CGPoint? = nil,
                      delta: (Int64, Int64) = (0, 0)) {
        let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p ?? cursor,
                        mouseButton: CGMouseButton(rawValue: UInt32(button))!)!
        e.setIntegerValueField(.mouseEventButtonNumber, value: button)
        e.setIntegerValueField(.mouseEventDeltaX, value: delta.0)
        e.setIntegerValueField(.mouseEventDeltaY, value: delta.1)
        e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
        e.post(tap: .cghidEventTap)
    }

    static func click(button: Int64) {
        mouse(.otherMouseDown, button: button)
        mouse(.otherMouseUp, button: button)
    }

    /// Segura o botão, arrasta em `steps` passos somando (dx, dy) e solta.
    static func drag(button: Int64, dx: Int64, dy: Int64, steps: Int64 = 10) {
        mouse(.otherMouseDown, button: button)
        for _ in 0..<steps {
            mouse(.otherMouseDragged, button: button, delta: (dx / steps, dy / steps))
            pause(0.01)
        }
        mouse(.otherMouseUp, button: button)
    }
}

// MARK: - Mesas (Spaces) — API privada do SkyLight

enum Spaces {
    private typealias ConnFn = @convention(c) () -> Int32
    private typealias SpaceFn = @convention(c) (Int32) -> UInt64
    private typealias CopyFn = @convention(c) (Int32) -> Unmanaged<CFArray>

    private static let lib = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
    private static let conn = unsafeBitCast(dlsym(lib, "SLSMainConnectionID"), to: ConnFn.self)()

    static func active() -> UInt64 {
        unsafeBitCast(dlsym(lib, "SLSGetActiveSpace"), to: SpaceFn.self)(conn)
    }

    private static func displays() -> [[String: Any]] {
        let copy = unsafeBitCast(dlsym(lib, "SLSCopyManagedDisplaySpaces"), to: CopyFn.self)
        return copy(conn).takeRetainedValue() as? [[String: Any]] ?? []
    }

    /// UUID da tela onde está o cursor — é nela que ⌃← / ⌃→ agem.
    static func cursorDisplayUUID() -> String {
        var id: CGDirectDisplayID = 0
        var n: UInt32 = 0
        CGGetDisplaysWithPoint(CGEvent(source: nil)!.location, 1, &id, &n)
        return CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()) as String
    }

    /// Estado da tela do cursor: mesa atual, lista de mesas em ordem e índice da atual.
    static func cursorDisplay() -> (current: UInt64, spaces: [UInt64], index: Int) {
        let uuid = cursorDisplayUUID()
        let d = displays().first { ($0["Display Identifier"] as? String) == uuid }
            ?? displays().first { ($0["Display Identifier"] as? String) == "Main" }
            ?? [:]
        let spaces = (d["Spaces"] as? [[String: Any]] ?? [])
            .compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
        let current = ((d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber)?.uint64Value ?? 0
        return (current, spaces, spaces.firstIndex(of: current) ?? 0)
    }
}

// MARK: - Visão geral (Mission Control / App Exposé)

enum Overview {
    /// Mission Control e App Exposé criam janelas do Dock nas camadas 18/20.
    static func isOpen() -> Bool {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.contains {
            ($0[kCGWindowOwnerName as String] as? String) == "Dock" &&
            [18, 20].contains($0[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    static func close() {
        if isOpen() { Inject.systemKey(53) } // Esc
        try? waitUntil("visão geral fechar") { !isOpen() }
    }
}

// MARK: - Clipboard

enum Clipboard {
    static var string: String? { NSPasteboard.general.string(forType: .string) }
    static func set(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
    static var hasImage: Bool {
        NSPasteboard.general.types?.contains(where: { [.png, .tiff].contains($0) }) ?? false
    }
}
