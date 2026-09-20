import Foundation

public enum OxygenLevel: Int, Comparable, Sendable {
    case normal, watch, low

    /// `percent` en escala 0-100.
    public init(percent: Double) {
        switch percent {
        case 95...: self = .normal
        case 90..<95: self = .watch
        default: self = .low
        }
    }

    public var title: String { switch self { case .normal: "normal"; case .watch: "algo baja"; case .low: "baja" } }

    public var message: String {
        switch self {
        case .normal: "en rango normal"
        case .watch: "repite la medición en reposo y quieto"
        case .low: "repite en reposo; si sigue baja, consulta a un médico"
        }
    }

    public static func < (a: OxygenLevel, b: OxygenLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum RestingHeart {
    public static func title(bpm: Double) -> String {
        switch bpm {
        case ..<50: "baja"
        case ..<100: "normal"
        default: "alta en reposo"
        }
    }
}
