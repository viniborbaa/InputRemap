// InputRemap — substitui o Logi Options+ para o mouse Lift.
// Uso: InputRemap [--deliver-to-pid <pid>] [--test-hang-button <n>]
// As duas flags são só para os testes E2E:
//   --deliver-to-pid    ⌘C/⌘V vão direto para esse processo (nunca para o app em foco)
//   --test-hang-button  ao receber esse botão, trava 3 s (provoca o desligamento do tap
//                       por demora, para testar que o app o religa sozinho)

import ApplicationServices
import CoreGraphics
import Foundation
import RemapCore
import RemapIO

final class Context {
    var remapper = Remapper()
    let poster: KeyPoster
    var tap: CFMachPort?
    init(poster: KeyPoster) { self.poster = poster }
}

let args = CommandLine.arguments
let deliverTo = args.firstIndex(of: "--deliver-to-pid").flatMap { i in
    i + 1 < args.count ? pid_t(args[i + 1]) : nil
}
let hangButton = args.firstIndex(of: "--test-hang-button").flatMap { i in
    i + 1 < args.count ? Int64(args[i + 1]) : nil
}
func log(_ s: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    FileHandle.standardError.write("\(stamp) \(s)\n".data(using: .utf8)!)
}

let context = Context(poster: KeyPoster(deliverTo: deliverTo))

let callback: CGEventTapCallBack = { _, type, event, info in
    let ctx = Unmanaged<Context>.fromOpaque(info!).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        log("tap desligado pelo macOS (\(type == .tapDisabledByTimeout ? "demora" : "entrada do usuário")); religando")
        if let t = ctx.tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    if let b = hangButton, type == .otherMouseDown, event.getIntegerValueField(.mouseEventButtonNumber) == b {
        Thread.sleep(forTimeInterval: 3)
    }
    // Instalado (sem --deliver-to-pid), ignora os eventos injetados pelo E2E: senão o app
    // do LaunchAgent também reagiria e mandaria ⌘C/⌘V para o app em foco do usuário.
    guard let input = EventTranslator.input(from: event, ignoringTestEvents: deliverTo == nil) else { return Unmanaged.passUnretained(event) }
    let decision = ctx.remapper.handle(input)
    decision.outputs.forEach(ctx.poster.post)
    return decision.swallow ? nil : Unmanaged.passUnretained(event)
}

let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) |
    (1 << CGEventType.otherMouseUp.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue)
func makeTap() -> CFMachPort? {
    CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                      eventsOfInterest: mask, callback: callback,
                      userInfo: Unmanaged.passUnretained(context).toOpaque())
}

var created = makeTap()
if created == nil {
    // Modo de teste: falha logo. Instalado (LaunchAgent com KeepAlive): sair faria o launchd
    // relançar em loop; em vez disso pede a permissão uma vez e espera ela ser concedida.
    if deliverTo != nil {
        log("erro: sem permissão para interceptar eventos (Acessibilidade)")
        exit(1)
    }
    log("aguardando permissão de Acessibilidade")
    _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    while created == nil {
        Thread.sleep(forTimeInterval: 2)
        created = makeTap()
    }
}
let tap = created!
context.tap = tap
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("pronto"); fflush(stdout)
CFRunLoopRun()
