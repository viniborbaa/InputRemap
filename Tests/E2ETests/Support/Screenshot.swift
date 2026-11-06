// Utilitários para os testes da tecla de print (Fase 7).
//
// A tecla de print do MX Keys S envia ⌘⇧4 nativo. A solução (opção A) é trocar os
// atalhos do macOS: ⌘⇧4 = região → clipboard; ⌃⇧⌘4 = região → arquivo.

import AppKit

enum ScreenshotShortcut {
    // IDs em com.apple.symbolichotkeys
    static let areaToFile = 30
    static let areaToClipboard = 31

    // Parâmetros (ASCII, keyCode, modificadores)
    static let cmdShift4: [Int] = [52, 21, 0x120000]
    static let ctrlCmdShift4: [Int] = [52, 21, 0x160000]

    /// Parâmetros e "enabled" do atalho `id` lidos das preferências do usuário.
    static func binding(_ id: Int) -> (enabled: Bool, params: [Int])? {
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
                .dictionary(forKey: "AppleSymbolicHotKeys"),
              let entry = all[String(id)] as? [String: Any],
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Int] else { return nil }
        return ((entry["enabled"] as? Bool) ?? false, params)
    }

    /// ⌘⇧4 está ligado a algum atalho de captura de região (então o macOS consome a tecla
    /// e ela não chega a nenhum app).
    static var cmdShift4IsSystemHotkey: Bool {
        [areaToFile, areaToClipboard].contains { id in
            binding(id).map { $0.enabled && $0.params == cmdShift4 } ?? false
        }
    }
}

enum ScreenCapture {
    /// Pasta onde o macOS salva as capturas em arquivo.
    static var saveDirectory: URL {
        let raw = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            ?? "~/Desktop"
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
    }

    static func files() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: saveDirectory.path)) ?? [])
    }

    /// A interface de seleção de região está na tela.
    /// Identificada pelo PID do processo screencaptureui (o nome da janela é localizado:
    /// aparece como "Screenshot").
    static var selectionIsOpen: Bool {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.screencaptureui")
            .map { Int($0.processIdentifier) })
        guard !pids.isEmpty else { return false }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.contains { pids.contains(($0[kCGWindowOwnerPID as String] as? Int) ?? -1) }
    }

    /// Arrasta com o botão esquerdo para selecionar uma região pequena ao redor do cursor.
    /// Só chamar com a seleção de região aberta (senão o arrasto cairia no app em foco).
    static func dragSmallRegion() {
        precondition(selectionIsOpen, "arrasto só com a seleção de região aberta")
        let start = Inject.cursor
        let end = CGPoint(x: start.x + 80, y: start.y + 60)
        func post(_ t: CGEventType, _ p: CGPoint) {
            let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: .left)!
            e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
            e.post(tap: .cghidEventTap)
        }
        post(.leftMouseDown, start)
        for i in 1...10 {
            let f = CGFloat(i) / 10
            post(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * f, y: start.y + (end.y - start.y) * f))
            pause(0.02)
        }
        post(.leftMouseUp, end)
    }
}

extension Inject {
    /// Simula a tecla de print (⌘⇧4). Só permitido quando ⌘⇧4 é atalho do sistema,
    /// para garantir que a tecla é consumida pelo macOS e nunca chega a um app.
    static func printKey() {
        precondition(ScreenshotShortcut.cmdShift4IsSystemHotkey, "⌘⇧4 não é atalho do sistema")
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: 21, keyDown: down)!
            e.flags = [.maskCommand, .maskShift]
            e.setIntegerValueField(.eventSourceUserData, value: testEventTag)
            e.post(tap: .cghidEventTap)
        }
    }
}
