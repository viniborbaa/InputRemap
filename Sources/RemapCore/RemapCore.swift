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
}

/// Ações semânticas; o RemapIO traduz cada uma para um atalho de teclado.
public enum Output: Equatable {
    case copy
    case paste
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
    public init() {}

    public mutating func handle(_ input: Input) -> Decision {
        switch input {
        case .mouseDown(Button.back): return Decision(swallow: true, outputs: [.copy])
        case .mouseDown(Button.forward): return Decision(swallow: true, outputs: [.paste])
        case .mouseUp(Button.back), .mouseUp(Button.forward): return Decision(swallow: true, outputs: [])
        default: return .passThrough
        }
    }
}
