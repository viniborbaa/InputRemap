// Janela de teste para o E2E.
//
// Uso: E2EHarness --text <texto inicial> --out <arquivo>
// - Abre uma janela com um campo de texto contendo <texto inicial>, todo selecionado.
// - Toma o foco (app em primeiro plano).
// - Grava o conteúdo atual do campo em <arquivo> ao abrir e a cada mudança.

import AppKit

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

let initialText = arg("--text") ?? ""
let outPath: String = arg("--out") ?? {
    FileHandle.standardError.write("faltou --out\n".data(using: .utf8)!)
    exit(2)
}()

final class Delegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var textView: NSTextView!

    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 420, height: 160),
                          styleMask: [.titled], backing: .buffered, defer: false)
        // --center x y: centro da janela em coordenadas globais (origem no canto superior
        // esquerdo da tela principal), para posicionar em outra tela.
        if let x = arg("--center").flatMap(Double.init),
           let i = CommandLine.arguments.firstIndex(of: "--center"), i + 2 < CommandLine.arguments.count,
           let y = Double(CommandLine.arguments[i + 2]) {
            let mainHeight = NSScreen.screens[0].frame.height
            window.setFrameOrigin(NSPoint(x: x - 210, y: mainHeight - y - 80))
        }
        window.title = "InputRemap E2E"
        textView = NSTextView(frame: window.contentView!.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.string = initialText
        textView.delegate = self
        window.contentView!.addSubview(textView)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        textView.selectAll(nil)
        NSApp.activate(ignoringOtherApps: true)
        persist()
        writeStatus()

        let nc = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in self?.writeStatus() }
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                if NSApp.isActive {
                    // A ativação pode terminar depois do launch: reafirma janela-chave e cursor no campo.
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(textView)
                }
                writeStatus()
            }
        }
    }

    func textDidChange(_ n: Notification) { persist() }

    func persist() {
        try? textView.string.write(toFile: outPath, atomically: true, encoding: .utf8)
    }

    /// "key" só quando o app está ativo, a janela é a janela-chave e o campo tem o cursor:
    /// é a única situação em que uma tecla injetada chega aqui.
    func writeStatus() {
        let ok = NSApp.isActive && window.isKeyWindow && window.firstResponder === textView
        try? (ok ? "key" : "nokey").write(toFile: outPath + ".status", atomically: true, encoding: .utf8)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Delegate()
app.delegate = delegate

// Menu Editar mínimo: sem ele, ⌘C/⌘V não chegam ao campo de texto.
let mainMenu = NSMenu()
let editItem = NSMenuItem()
mainMenu.addItem(editItem)
let edit = NSMenu(title: "Edit")
edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editItem.submenu = edit
app.mainMenu = mainMenu

app.run()
