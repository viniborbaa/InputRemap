// InputRemap — substitui o Logi Options+ para o mouse Lift.
// Uso: InputRemap [--deliver-to-pid <pid>] [--test-hang-button <n>]
// As duas flags são só para os testes E2E:
//   --deliver-to-pid    ⌘C/⌘V vão direto para esse processo (nunca para o app em foco)
//   --test-hang-button  ao receber esse botão, trava 3 s (provoca o desligamento do tap
//                       por demora, para testar que o app o religa sozinho)

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
let context = Context(poster: KeyPoster(deliverTo: deliverTo))

let callback: CGEventTapCallBack = { _, type, event, info in
    let ctx = Unmanaged<Context>.fromOpaque(info!).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = ctx.tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    if let b = hangButton, type == .otherMouseDown, event.getIntegerValueField(.mouseEventButtonNumber) == b {
        Thread.sleep(forTimeInterval: 3)
    }
    guard let input = EventTranslator.input(from: event) else { return Unmanaged.passUnretained(event) }
    let decision = ctx.remapper.handle(input)
    decision.outputs.forEach(ctx.poster.post)
    return decision.swallow ? nil : Unmanaged.passUnretained(event)
}

let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue) |
    (1 << CGEventType.otherMouseUp.rawValue) |
    (1 << CGEventType.otherMouseDragged.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                  eventsOfInterest: mask, callback: callback,
                                  userInfo: Unmanaged.passUnretained(context).toOpaque()) else {
    FileHandle.standardError.write("erro: sem permissão para interceptar eventos (Acessibilidade)\n".data(using: .utf8)!)
    exit(1)
}
context.tap = tap
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("pronto"); fflush(stdout)
CFRunLoopRun()
