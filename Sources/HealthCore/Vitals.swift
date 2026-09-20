import Foundation
import Localization

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

    public var title: String { switch self { case .normal: L10n.tr("normal"); case .watch: L10n.tr("algo baja"); case .low: L10n.tr("baja") } }

    public var message: String {
        switch self {
        case .normal: L10n.tr("en rango normal")
        case .watch: L10n.tr("repite la medición en reposo y quieto")
        case .low: L10n.tr("repite en reposo; si sigue baja, consulta a un médico")
        }
    }

    public static func < (a: OxygenLevel, b: OxygenLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum RestingHeart {
    public static func title(bpm: Double) -> String {
        switch bpm {
        case ..<50: L10n.tr("baja")
        case ..<100: L10n.tr("normal")
        default: L10n.tr("alta en reposo")
        }
    }
}
