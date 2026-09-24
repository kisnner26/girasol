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

/// promedio de variabilidad del pulso (sdnn, en ms) de los ultimos dias contra los anteriores: una comparacion, no un diagnostico.
public struct HRVTrend: Equatable, Sendable {
    public var recentAvgMs: Double
    public var previousAvgMs: Double
    public var deltaMs: Double { recentAvgMs - previousAvgMs }

    public init(recentAvgMs: Double, previousAvgMs: Double) {
        self.recentAvgMs = recentAvgMs; self.previousAvgMs = previousAvgMs
    }
}

public enum HeartVariability {
    /// compara el promedio de los ultimos `days` dias con el de los `days` anteriores; nil si falta algun lado.
    public static func trend(samples: [(date: Date, sdnnMs: Double)], today: Date, days: Int = 7, calendar: Calendar = .current) -> HRVTrend? {
        let start = calendar.startOfDay(for: today)
        guard let recentStart = calendar.date(byAdding: .day, value: -(days - 1), to: start),
              let previousStart = calendar.date(byAdding: .day, value: -(2 * days - 1), to: start),
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: recentStart),
              let previousEndExclusive = calendar.date(byAdding: .day, value: 1, to: previousEnd) else { return nil }

        let recent = samples.filter { $0.date >= recentStart && $0.date <= today }.map(\.sdnnMs)
        let previous = samples.filter { $0.date >= previousStart && $0.date < previousEndExclusive }.map(\.sdnnMs)
        guard !recent.isEmpty, !previous.isEmpty else { return nil }

        func avg(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(xs.count) }
        return HRVTrend(recentAvgMs: avg(recent), previousAvgMs: avg(previous))
    }
}
