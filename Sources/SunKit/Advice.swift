import Foundation
import Localization

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

/// riesgo de congelacion en piel expuesta, segun la sensacion termica (open-meteo ya incluye el viento en `apparent_temperature`).
public enum ColdRisk: Int, Comparable, Sendable {
    case none, caution, high, extreme

    public init(apparent: Double) {
        if apparent < -25 { self = .extreme }
        else if apparent < -15 { self = .high }
        else if apparent < -5 { self = .caution }
        else { self = .none }
    }

    public static func < (a: ColdRisk, b: ColdRisk) -> Bool { a.rawValue < b.rawValue }

    public var message: String {
        switch self {
        case .none: L10n.tr("sin riesgo de congelación")
        case .caution: L10n.tr("piel expuesta puede congelarse en 30-60 min; cúbrete")
        case .high: L10n.tr("piel expuesta puede congelarse en 10-30 min; abrígate bien")
        case .extreme: L10n.tr("piel expuesta puede congelarse en menos de 10 min; evita salir así")
        }
    }
}

public struct Advice: Sendable, Equatable {
    public let level: AdviceLevel
    public let headline: String
    public let detail: String
    public let heat: HeatLevel
    public let coldRisk: ColdRisk
}

/// "¿puedo salir ahora?" a partir del uv, el calor y lo que ya llevas recibido hoy.
public enum Advisor {
    public static func advice(uvi: Double, apparent: Double, isDay: Bool, usedFraction: Double) -> Advice {
        let heat = HeatLevel(apparent: apparent)
        let cold = ColdRisk(apparent: apparent)

        if !isDay {
            return Advice(level: cold >= .caution ? .avoid : .ok, headline: L10n.tr("es de noche"),
                          detail: cold >= .caution ? cold.message : L10n.tr("sin radiación uv ahora"), heat: heat, coldRisk: cold)
        }

        var level: AdviceLevel
        var headline: String
        var detail: String
        switch UVCategory(uvi: uvi) {
        case .low:
            (level, headline, detail) = (.ok, L10n.tr("sin problema"), L10n.tr("uv bajo, puedes salir"))
        case .moderate:
            (level, headline, detail) = (.care, L10n.tr("con protección"), L10n.tr("protector si vas a estar más de media hora"))
        case .high:
            (level, headline, detail) = (.care, L10n.tr("con cuidado"), L10n.tr("protector, sombrero y sombra cuando puedas"))
        case .veryHigh:
            (level, headline, detail) = (.avoid, L10n.tr("mejor evitar"), L10n.tr("uv muy alto, sal solo lo necesario"))
        case .extreme:
            (level, headline, detail) = (.stay, L10n.tr("quédate en la sombra"), L10n.tr("uv extremo, la piel se daña en minutos"))
        }

        if usedFraction >= 1 {
            (level, headline, detail) = (.stay, L10n.tr("límite superado"), L10n.tr("tu piel ya recibió hoy lo que tolera: sombra"))
        } else if usedFraction >= 0.8, level < .avoid {
            (level, headline, detail) = (.avoid, L10n.tr("cerca de tu límite"), L10n.tr("te queda poco margen hoy, busca sombra"))
        }

        switch heat {
        case .danger:
            level = max(level, .avoid)
            detail += "; " + L10n.tr("calor extremo, hidrátate")
        case .hot:
            detail += "; " + L10n.tr("hace calor, hidrátate")
        case .cold:
            detail += "; " + L10n.tr("hace frío")
        default:
            break
        }

        switch cold {
        case .none: break
        case .caution:
            level = max(level, .care)
            detail += "; " + cold.message
        case .high, .extreme:
            level = max(level, .avoid)
            detail += "; " + cold.message
        }
        return Advice(level: level, headline: headline, detail: detail, heat: heat, coldRisk: cold)
    }
}
