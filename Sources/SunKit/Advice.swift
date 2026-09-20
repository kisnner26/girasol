import Foundation

public enum HeatLevel: Int, Comparable, Sendable {
    case cold, comfortable, warm, hot, danger

    /// sensacion termica en °c.
    public init(apparent: Double) {
        switch apparent {
        case ..<10: self = .cold
        case ..<28: self = .comfortable
        case ..<32: self = .warm
        case ..<38: self = .hot
        default: self = .danger
        }
    }

    public static func < (a: HeatLevel, b: HeatLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum AdviceLevel: Int, Comparable, Sendable {
    case ok, care, avoid, stay
    public static func < (a: AdviceLevel, b: AdviceLevel) -> Bool { a.rawValue < b.rawValue }
}

public struct Advice: Sendable, Equatable {
    public let level: AdviceLevel
    public let headline: String
    public let detail: String
    public let heat: HeatLevel
}

/// "¿puedo salir ahora?" a partir del uv, el calor y lo que ya llevas recibido hoy.
public enum Advisor {
    public static func advice(uvi: Double, apparent: Double, isDay: Bool, usedFraction: Double) -> Advice {
        let heat = HeatLevel(apparent: apparent)

        if !isDay {
            return Advice(level: .ok, headline: "es de noche", detail: "sin radiación uv ahora", heat: heat)
        }

        var level: AdviceLevel
        var headline: String
        var detail: String
        switch UVCategory(uvi: uvi) {
        case .low:
            (level, headline, detail) = (.ok, "sin problema", "uv bajo, puedes salir")
        case .moderate:
            (level, headline, detail) = (.care, "con protección", "protector si vas a estar más de media hora")
        case .high:
            (level, headline, detail) = (.care, "con cuidado", "protector, sombrero y sombra cuando puedas")
        case .veryHigh:
            (level, headline, detail) = (.avoid, "mejor evitar", "uv muy alto, sal solo lo necesario")
        case .extreme:
            (level, headline, detail) = (.stay, "quédate en la sombra", "uv extremo, la piel se daña en minutos")
        }

        if usedFraction >= 1 {
            (level, headline, detail) = (.stay, "límite superado", "tu piel ya recibió hoy lo que tolera: sombra")
        } else if usedFraction >= 0.8, level < .avoid {
            (level, headline, detail) = (.avoid, "cerca de tu límite", "te queda poco margen hoy, busca sombra")
        }

        switch heat {
        case .danger:
            level = max(level, .avoid)
            detail += "; calor extremo, hidrátate"
        case .hot:
            detail += "; hace calor, hidrátate"
        case .cold:
            detail += "; hace frío"
        default:
            break
        }
        return Advice(level: level, headline: headline, detail: detail, heat: heat)
    }
}
