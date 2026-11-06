// Gravador de eventos para a Fase 1 (descoberta do hardware).
// Só ESCUTA (listenOnly): não bloqueia nem altera nada.
// Registra botões de mouse, códigos de tecla e teclas de sistema (mídia/especiais).
// Não registra caracteres digitados, só códigos. Encerra sozinho após --seconds (padrão 600).

import AppKit

let seconds = Double(CommandLine.arguments.drop(while: { $0 != "--seconds" }).dropFirst().first ?? "600") ?? 600

func out(_ s: String) {
    let t = String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
    print("\(t) \(s)"); fflush(stdout)
}

let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .keyDown, .keyUp, .flagsChanged]
var mask: CGEventMask = 1 << 14 // NX_SYSDEFINED
for t in types { mask |= 1 << t.rawValue }

let cb: CGEventTapCallBack = { _, type, e, _ in
    switch type {
    case .otherMouseDown, .otherMouseUp:
        out("MOUSE \(type == .otherMouseDown ? "down" : "up  ") botão=\(e.getIntegerValueField(.mouseEventButtonNumber))")
    case .keyDown, .keyUp:
        out("TECLA \(type == .keyDown ? "down" : "up  ") keyCode=\(e.getIntegerValueField(.keyboardEventKeycode)) flags=0x\(String(e.flags.rawValue, radix: 16))")
    case .flagsChanged:
        out("MODIF keyCode=\(e.getIntegerValueField(.keyboardEventKeycode)) flags=0x\(String(e.flags.rawValue, radix: 16))")
    default:
        if type.rawValue == 14, let ns = NSEvent(cgEvent: e) {
            let d = ns.data1
            out("SISTEMA subtype=\(ns.subtype.rawValue) key=\((d & 0xFFFF0000) >> 16) estado=0x\(String((d & 0xFF00) >> 8, radix: 16)) data1=0x\(String(d, radix: 16))")
        } else {
            out("OUTRO tipo=\(type.rawValue)")
        }
    }
    return Unmanaged.passUnretained(e)
}

guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
                                  eventsOfInterest: mask, callback: cb, userInfo: nil) else {
    out("ERRO: não consegui criar o tap (permissão?)"); exit(1)
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
out("gravando por \(Int(seconds))s")
CFRunLoopRunInMode(.defaultMode, seconds, false)
out("fim")
