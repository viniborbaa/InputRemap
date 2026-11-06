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
        pause(0.05)
    }
    throw E2EError.timeout(what)
}

/// Espera `s` segundos. Fora da main thread (onde o Swift Testing roda os testes) o RunLoop
/// não tem fontes e `run(until:)` volta na hora, então dorme a thread.
func pause(_ s: TimeInterval) {
    if Thread.isMainThread { RunLoop.current.run(until: Date().addingTimeInterval(s)) }
    else { Thread.sleep(forTimeInterval: s) }
}

// MARK: - Injeção

enum Inject {
    static let arrowFlags: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]

    /// Teclas que podem ir para o sistema todo: só setas (com ⌃ = atalhos de mesa/Mission
    /// Control, sempre consumidos pelo macOS). Qualquer outra tecla global poderia cair no
    /// app em foco — inclusive o Terminal, onde Esc interrompe o Claude Code (incidentes 1–3).
    static let globalAllowed: Set<CGKeyCode> = [123, 124, 125, 126]

    /// Atalho de sistema, postado globalmente. Só ⌃ + setas.
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

    /// Clique esquerdo ou direito num ponto (cai na janela sob o ponto).
    static func click(_ down: CGEventType, _ up: CGEventType, at p: CGPoint) {
        for t in [down, up] {
            let btn: CGMouseButton = t == .rightMouseDown || t == .rightMouseUp ? .right : .left
            let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: btn)!
            e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
            e.post(tap: .cghidEventTap)
        }
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

    /// Uma tela com 2+ mesas (UUID e retângulo em coordenadas globais), se existir.
    static func displayWithMultipleSpaces() -> (uuid: String, bounds: CGRect)? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var n: UInt32 = 0
        CGGetActiveDisplayList(8, &ids, &n)
        for d in displays() {
            // Só mesas comuns (type 0). Espaços de app em tela cheia (type 4) ficam de fora:
            // alternar para eles esconderia o app do usuário (ex.: Terminal em tela cheia).
            let regular = (d["Spaces"] as? [[String: Any]] ?? []).filter { ($0["type"] as? Int) == 0 }
            guard let uuid = d["Display Identifier"] as? String, regular.count >= 2 else { continue }
            for id in ids.prefix(Int(n)) {
                let u = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()) as String
                if u == uuid || (uuid == "Main" && id == CGMainDisplayID()) {
                    return (uuid, CGDisplayBounds(id))
                }
            }
        }
        return nil
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

    /// Fecha a visão geral com o mesmo atalho que a abriu (⌃↑ Mission Control, ⌃↓ App
    /// Exposé), que funciona como liga/desliga e é sempre consumido pelo macOS.
    /// Nunca usa Esc: sem sobreposição aberta, o Esc cairia no Terminal e interromperia
    /// o Claude Code (incidente 3). Espera antes, porque a visão geral pode abrir com atraso.
    static func close(toggle: CGKeyCode) {
        precondition([125, 126].contains(toggle), "fechar só com ⌃↑ ou ⌃↓")
        _ = try? waitUntil("visão geral aparecer (se for abrir)", timeout: 0.6) { isOpen() }
        guard isOpen() else { return }
        Inject.systemKey(toggle, .maskControl)
        try? waitUntil("visão geral fechar") { !isOpen() }
    }
}

// MARK: - Launchpad

enum Launchpad {
    static let url = URL(fileURLWithPath: "/System/Applications/Launchpad.app")

    /// O Launchpad cria janelas do Dock nas camadas 27/29.
    static func isOpen() -> Bool {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.contains {
            ($0[kCGWindowOwnerName as String] as? String) == "Dock" &&
            [27, 29].contains($0[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// Fecha abrindo o Launchpad.app de novo (liga/desliga). Nunca Esc (incidente 3).
    static func close() {
        _ = try? waitUntil("Launchpad aparecer (se for abrir)", timeout: 0.6) { isOpen() }
        guard isOpen() else { return }
        LSOpenCFURLRef(url as CFURL, nil)
        // A animação de saída passa por janelas nas camadas da visão geral (18/20):
        // espera tudo sumir, senão o próximo teste acha uma visão geral "aberta".
        try? waitUntil("Launchpad fechar") { !isOpen() && !Overview.isOpen() }
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
