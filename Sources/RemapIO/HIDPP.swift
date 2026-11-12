// Tecla da calculadora do MX Keys S via HID++ (protocolo da Logitech).
//
// No modo Mac, o teclado não envia nada ao macOS por essa tecla: quem a tratava era o
// Options+, que a "desviava" pelo HID++. Aqui fazemos o mesmo: pedimos ao teclado para
// avisar os apertos (feature 0x1B04, setCidReporting com divert) e abrimos a Calculadora.
// O desvio é volátil: o teclado o esquece ao reconectar, por isso é refeito a cada conexão.

import Foundation
import IOKit.hid
import RemapCore

public enum HIDPP {
    static let longReport: UInt8 = 0x11
    static let deviceIndex: UInt8 = 0xFF  // conexão direta (Bluetooth), sem receptor
    static let softwareID: UInt8 = 0x0A   // marca nossas perguntas; avisos do teclado vêm com 0
    static let reprogControls: UInt16 = 0x1B04
    public static let calculatorCID: UInt16 = 0x000A

    static func request(feature: UInt8, function: UInt8, _ params: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: 20)
        r[0] = longReport; r[1] = deviceIndex; r[2] = feature; r[3] = function << 4 | softwareID
        r.replaceSubrange(4..<4 + params.count, with: params)
        return r
    }

    /// Root (índice 0), função 0: índice da feature pedida.
    static func getFeature(_ id: UInt16) -> [UInt8] {
        request(feature: 0, function: 0, [UInt8(id >> 8), UInt8(id & 0xFF)])
    }

    /// 0x1B04, função 3 (setCidReporting): divert + dvalid.
    static func divert(cid: UInt16, featureIndex: UInt8) -> [UInt8] {
        request(feature: featureIndex, function: 3, [UInt8(cid >> 8), UInt8(cid & 0xFF), 0x03])
    }

    enum Message: Equatable {
        case featureIndex(UInt8)
        /// Teclas desviadas apertadas agora (vazio = todas soltas).
        case pressed([UInt16])
    }

    static func parse(_ r: [UInt8], reprogIndex: UInt8?) -> Message? {
        guard r.count >= 20, r[0] == longReport else { return nil }
        if r[2] == 0, r[3] == softwareID {
            return r[4] == 0 ? nil : .featureIndex(r[4])
        }
        guard let idx = reprogIndex, r[2] == idx, r[3] == 0 else { return nil }
        let cids = stride(from: 4, to: 12, by: 2).map { UInt16(r[$0]) << 8 | UInt16(r[$0 + 1]) }
        return .pressed(cids.filter { $0 != 0 })
    }
}

/// Transforma a lista de teclas apertadas em um disparo por aperto.
struct DivertedKey {
    let cid: UInt16
    var down = false

    mutating func update(_ pressed: [UInt16]) -> Bool {
        let now = pressed.contains(cid)
        defer { down = now }
        return now && !down
    }
}

/// Liga a tecla da calculadora em todo teclado Logitech conectado (inclusive reconexões).
public final class LogitechKeys {
    final class Device {
        let hid: IOHIDDevice
        var reprogIndex: UInt8?
        var calculator = DivertedKey(cid: HIDPP.calculatorCID)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        init(_ hid: IOHIDDevice) { self.hid = hid }
        deinit { buffer.deallocate() }
    }

    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    var devices: [IOHIDDevice: Device] = [:]
    let onPress: (Output) -> Void
    let log: (String) -> Void

    public init(onPress: @escaping (Output) -> Void, log: @escaping (String) -> Void) {
        self.onPress = onPress
        self.log = log
    }

    /// Sem permissão de Monitoramento de Entrada, pede uma vez e tenta de novo a cada 3 s.
    public func start() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x046D,
            kIOHIDPrimaryUsagePageKey: 0x01,
            kIOHIDPrimaryUsageKey: 0x06,
        ] as CFDictionary)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, hid in
            Unmanaged<LogitechKeys>.fromOpaque(ctx!).takeUnretainedValue().attach(hid)
        }, me)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, hid in
            Unmanaged<LogitechKeys>.fromOpaque(ctx!).takeUnretainedValue().devices[hid] = nil
        }, me)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        if open() { return }
        log("teclado: aguardando permissão de Monitoramento de Entrada")
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] t in
            if self?.open() ?? true { t.invalidate() }
        }
    }

    func open() -> Bool {
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
    }

    func attach(_ hid: IOHIDDevice) {
        let d = Device(hid)
        devices[hid] = d
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(hid, d.buffer, 64, { ctx, _, sender, _, _, report, len in
            guard let sender else { return }
            let me = Unmanaged<LogitechKeys>.fromOpaque(ctx!).takeUnretainedValue()
            let hid = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
            me.received(Array(UnsafeBufferPointer(start: report, count: len)), from: hid)
        }, me)
        send(HIDPP.getFeature(HIDPP.reprogControls), to: hid)
    }

    func received(_ report: [UInt8], from hid: IOHIDDevice) {
        guard let d = devices[hid] else { return }
        switch HIDPP.parse(report, reprogIndex: d.reprogIndex) {
        case let .featureIndex(i)?:
            d.reprogIndex = i
            send(HIDPP.divert(cid: HIDPP.calculatorCID, featureIndex: i), to: hid)
            log("teclado: tecla da calculadora ligada")
        case let .pressed(cids)?:
            if d.calculator.update(cids) { onPress(.calculator) }
        case nil: break
        }
    }

    func send(_ r: [UInt8], to hid: IOHIDDevice) {
        let st = IOHIDDeviceSetReport(hid, kIOHIDReportTypeOutput, CFIndex(r[0]), r, r.count)
        if st != kIOReturnSuccess { log("teclado: falha ao enviar HID++ (0x\(String(UInt32(bitPattern: st), radix: 16)))") }
    }
}
