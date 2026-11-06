// Núcleo puro: recebe eventos de entrada e decide o que fazer. Sem dependência de macOS.

/// Números de botão do Lift sem o Logi Options+ (descobertos na Fase 1).
public enum Button {
    public static let middle = 2
    public static let back = 3
    public static let forward = 4
}

public enum Input: Equatable {
    case mouseDown(button: Int)
    case mouseUp(button: Int)
    case mouseDragged(button: Int, dx: Double, dy: Double)
}

/// Ações semânticas; o RemapIO traduz cada uma para um atalho de teclado.
public enum Output: Equatable {
    case copy
    case paste
    case missionControl
    case launchpad
    case spaceLeft
    case spaceRight
}

public struct Decision: Equatable {
    public var swallow: Bool
    public var outputs: [Output]

    public init(swallow: Bool, outputs: [Output]) {
        self.swallow = swallow
        self.outputs = outputs
    }

    public static let passThrough = Decision(swallow: false, outputs: [])
}

public struct Remapper {
    /// Gesto em andamento com o botão do meio pressionado.
    struct Gesture {
        var dx: Double = 0
        var dy: Double = 0
        var fired = false
    }

    var gesture: Gesture?

    /// Pixels de arrasto acumulado até o gesto disparar.
    public static let threshold: Double = 60

    /// Gesto correspondente ao arrasto acumulado, ou nil se ainda não passou do limiar.
    /// Eixo dominante decide. Coordenadas de tela: y negativo = para cima.
    static func direction(dx: Double, dy: Double) -> Output? {
        guard max(abs(dx), abs(dy)) > threshold else { return nil }
        if abs(dy) >= abs(dx) { return dy < 0 ? .missionControl : .launchpad }
        return dx < 0 ? .spaceLeft : .spaceRight
    }

    public init() {}

    public mutating func handle(_ input: Input) -> Decision {
        switch input {
        case .mouseDown(Button.back): return Decision(swallow: true, outputs: [.copy])
        case .mouseDown(Button.forward): return Decision(swallow: true, outputs: [.paste])
        case .mouseUp(Button.back), .mouseUp(Button.forward): return Decision(swallow: true, outputs: [])

        case .mouseDown(Button.middle):
            gesture = Gesture()
            return Decision(swallow: true, outputs: [])
        case let .mouseDragged(Button.middle, dx, dy):
            guard var g = gesture else { return .passThrough }
            g.dx += dx
            g.dy += dy
            var outputs: [Output] = []
            if !g.fired, let out = Self.direction(dx: g.dx, dy: g.dy) {
                g.fired = true
                outputs = [out]
            }
            gesture = g
            return Decision(swallow: true, outputs: outputs)
        case .mouseUp(Button.middle):
            defer { gesture = nil }
            guard let g = gesture else { return .passThrough }
            return Decision(swallow: true, outputs: g.fired ? [] : [.missionControl])

        default: return .passThrough
        }
    }
}

/// Rodinha do mouse no sentido oposto ao do trackpad. A "rolagem natural" do macOS vale para
/// os dois; a rodinha (rolagem em passos, não contínua) é invertida, o trackpad não.
public enum ScrollPolicy {
    public static func shouldInvert(continuous: Bool) -> Bool { !continuous }
}
