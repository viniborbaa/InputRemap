// Guarda e restaura o espaço (mesa ou app em tela cheia) de cada tela em volta do E2E.
//
//   E2ESpaces save <arquivo>     anota espaço atual de cada tela + posição do cursor
//   E2ESpaces prepare            tela principal: se estiver num app em tela cheia, vai
//                                para a mesa comum mais próxima (a janela de teste abre ali)
//   E2ESpaces restore <arquivo>  volta cada tela ao espaço anotado e o cursor ao lugar
//
// Só usa ⌃← / ⌃→ (atalhos consumidos pelo macOS) e movimento do cursor.

import AppKit

typealias ConnFn = @convention(c) () -> Int32
typealias CopyFn = @convention(c) (Int32) -> Unmanaged<CFArray>
let lib = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
let conn = unsafeBitCast(dlsym(lib, "SLSMainConnectionID"), to: ConnFn.self)()

struct Display {
    let uuid: String
    let current: UInt64
    let spaces: [(id: UInt64, regular: Bool)]
}

func displays() -> [Display] {
    let raw = unsafeBitCast(dlsym(lib, "SLSCopyManagedDisplaySpaces"), to: CopyFn.self)(conn)
        .takeRetainedValue() as? [[String: Any]] ?? []
    return raw.compactMap { d in
        guard let uuid = d["Display Identifier"] as? String,
              let cur = ((d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber)?.uint64Value
        else { return nil }
        let spaces = (d["Spaces"] as? [[String: Any]] ?? []).compactMap { s -> (UInt64, Bool)? in
            guard let id = (s["ManagedSpaceID"] as? NSNumber)?.uint64Value else { return nil }
            return (id, (s["type"] as? Int) == 0)
        }
        return Display(uuid: uuid, current: cur, spaces: spaces)
    }
}

func displayID(for uuid: String) -> CGDirectDisplayID? {
    var ids = [CGDirectDisplayID](repeating: 0, count: 8)
    var n: UInt32 = 0
    CGGetActiveDisplayList(8, &ids, &n)
    return ids.prefix(Int(n)).first {
        (CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID($0).takeRetainedValue()) as String) == uuid
            || (uuid == "Main" && $0 == CGMainDisplayID())
    }
}

func moveCursor(_ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.2)
}

func arrow(_ code: CGKeyCode) {
    for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
        e.flags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
        e.post(tap: .cghidEventTap)
    }
}

/// Anda com ⌃←/⌃→ na tela `uuid` até chegar em `target`.
func go(_ uuid: String, to target: UInt64) -> Bool {
    guard let did = displayID(for: uuid) else { return false }
    let b = CGDisplayBounds(did)
    moveCursor(CGPoint(x: b.midX, y: b.midY))
    for _ in 0..<8 {
        guard let d = displays().first(where: { $0.uuid == uuid }) else { return false }
        if d.current == target { return true }
        let ids = d.spaces.map(\.id)
        guard let from = ids.firstIndex(of: d.current), let to = ids.firstIndex(of: target) else { return false }
        arrow(to > from ? 124 : 123)
        Thread.sleep(forTimeInterval: 1.0)
    }
    return displays().first { $0.uuid == uuid }?.current == target
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "save":
    let cursor = CGEvent(source: nil)!.location
    var state: [String: Any] = ["cursor": [cursor.x, cursor.y]]
    for d in displays() { state[d.uuid] = d.current }
    let data = try! JSONSerialization.data(withJSONObject: state)
    try! data.write(to: URL(fileURLWithPath: args[2]))
    print("espaços anotados: \(displays().map { "\($0.uuid.prefix(8))=\($0.current)" }.joined(separator: " "))")

case "prepare":
    let mainUUID = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(CGMainDisplayID()).takeRetainedValue()) as String
    guard let d = displays().first(where: { $0.uuid == mainUUID || $0.uuid == "Main" }) else { exit(0) }
    if d.spaces.first(where: { $0.id == d.current })?.regular == true { print("tela principal já numa mesa comum"); exit(0) }
    let ids = d.spaces.map(\.id)
    let i = ids.firstIndex(of: d.current) ?? 0
    let nearest = d.spaces.enumerated().filter { $0.element.regular }.min { abs($0.offset - i) < abs($1.offset - i) }
    if let n = nearest, go(d.uuid, to: n.element.id) { print("tela principal → mesa comum \(n.element.id)") }
    else { print("aviso: não achei mesa comum na tela principal"); exit(1) }

case "restore":
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: args[2])),
          let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { exit(1) }
    var ok = true
    for d in displays() {
        if let target = (state[d.uuid] as? NSNumber)?.uint64Value, d.current != target {
            ok = go(d.uuid, to: target) && ok
        }
    }
    if let c = state["cursor"] as? [Double], c.count == 2 { moveCursor(CGPoint(x: c[0], y: c[1])) }
    print(ok ? "espaços restaurados" : "aviso: nem todos os espaços foram restaurados")
    exit(ok ? 0 : 1)

default:
    print("uso: E2ESpaces save|prepare|restore [arquivo]")
    exit(2)
}
