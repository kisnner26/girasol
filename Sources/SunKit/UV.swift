import Foundation
import Localization

/// categorias del indice uv de la oms.
public enum UVCategory: Int, CaseIterable, Comparable, Sendable {
    case low, moderate, high, veryHigh, extreme

    public init(uvi: Double) {
        switch uvi {
        case ..<3: self = .low
        case ..<6: self = .moderate
        case ..<8: self = .high
        case ..<11: self = .veryHigh
        default: self = .extreme
        }
    }

    public var name: String {
        switch self {
        case .low: L10n.tr("bajo")
        case .moderate: L10n.tr("moderado")
        case .high: L10n.tr("alto")
        case .veryHigh: L10n.tr("muy alto")
        case .extreme: L10n.tr("extremo")
        }
    }

    /// indice uv a partir del cual empieza la categoria.
    public var lowerBound: Double {
        switch self {
        case .low: 0
        case .moderate: 3
        case .high: 6
        case .veryHigh: 8
        case .extreme: 11
        }
    }

    public static func < (a: UVCategory, b: UVCategory) -> Bool { a.rawValue < b.rawValue }
}

/// fototipo de fitzpatrick. la dosis eritemica minima (med) es una aproximacion
/// tipica por fototipo, no una medicion de tu piel.
public enum SkinType: Int, CaseIterable, Codable, Sendable {
    case i = 1, ii, iii, iv, v, vi

    /// j/m2 de radiacion eritemica que producen un enrojecimiento minimo.
    public var medJoulesPerSquareMeter: Double {
        switch self {
        case .i: 200
        case .ii: 250
        case .iii: 300
        case .iv: 450
        case .v: 600
        case .vi: 900
        }
    }

    public var title: String { L10n.tr("tipo %@", ["I", "II", "III", "IV", "V", "VI"][rawValue - 1]) }

    public var detail: String {
        switch self {
        case .i: L10n.tr("muy clara, siempre se quema")
        case .ii: L10n.tr("clara, se quema fácil")
        case .iii: L10n.tr("media, a veces se quema")
        case .iv: L10n.tr("morena clara, rara vez se quema")
        case .v: L10n.tr("morena, casi nunca se quema")
        case .vi: L10n.tr("oscura, muy rara vez se quema")
        }
    }
}

/// factor de proteccion solar. el spf de etiqueta se mide con una capa gruesa que casi nadie
/// aplica, asi que se toma la mitad como factor efectivo.
public struct Sunscreen: Hashable, Codable, Sendable {
    public let spf: Int
    public init(spf: Int) { self.spf = spf }
    public static let none = Sunscreen(spf: 0)
    public static let options: [Sunscreen] = [0, 15, 30, 50].map(Sunscreen.init(spf:))

    public var protectionFactor: Double { spf <= 0 ? 1 : max(1, Double(spf) * 0.5) }
    public var title: String { spf <= 0 ? L10n.tr("sin protector") : "SPF \(spf)" }
}
