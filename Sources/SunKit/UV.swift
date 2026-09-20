import Foundation

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
        case .low: "bajo"
        case .moderate: "moderado"
        case .high: "alto"
        case .veryHigh: "muy alto"
        case .extreme: "extremo"
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

    public var title: String { "tipo " + ["I", "II", "III", "IV", "V", "VI"][rawValue - 1] }

    public var detail: String {
        switch self {
        case .i: "muy clara, siempre se quema"
        case .ii: "clara, se quema fácil"
        case .iii: "media, a veces se quema"
        case .iv: "morena clara, rara vez se quema"
        case .v: "morena, casi nunca se quema"
        case .vi: "oscura, muy rara vez se quema"
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
    public var title: String { spf <= 0 ? "sin protector" : "spf \(spf)" }
}
