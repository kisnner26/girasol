import Foundation

/// un indice uv de 1 equivale a 0.025 w/m2 de irradiancia eritemica = 1.5 j/m2 por minuto.
public enum Exposure {
    public static let joulesPerMinutePerUVI = 1.5

    /// j/m2 recibidos en `minutes` a `uvi`, ya divididos por el factor de proteccion.
    public static func dose(uvi: Double, minutes: Double, protection: Double = 1) -> Double {
        guard uvi > 0, minutes > 0 else { return 0 }
        return uvi * joulesPerMinutePerUVI * minutes / max(1, protection)
    }

    /// 1.0 = has recibido tu dosis eritemica minima.
    public static func fractionOfLimit(dose: Double, skin: SkinType) -> Double {
        dose / skin.medJoulesPerSquareMeter
    }

    /// minutos que faltan para el limite a este uv. nil si el uv es tan bajo que no hay limite practico.
    public static func minutesToLimit(uvi: Double, usedFraction: Double, skin: SkinType, protection: Double = 1) -> Double? {
        guard uvi >= 0.5 else { return nil }
        let remaining = max(0, 1 - usedFraction) * skin.medJoulesPerSquareMeter
        return remaining / (uvi * joulesPerMinutePerUVI / max(1, protection))
    }
}

/// uv por hora con interpolacion lineal entre puntos.
public struct UVCurve: Sendable, Equatable {
    public let points: [(date: Date, uvi: Double)]

    public init(hours: [WeatherSnapshot.Hour]) {
        points = hours.sorted { $0.start < $1.start }.map { ($0.start, $0.uvIndex) }
    }

    public static func == (a: UVCurve, b: UVCurve) -> Bool {
        a.points.count == b.points.count && zip(a.points, b.points).allSatisfy { $0.date == $1.date && $0.uvi == $1.uvi }
    }

    public func uvi(at date: Date) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if date <= first.date { return first.uvi }
        if date >= last.date { return last.uvi }
        for i in 1..<points.count where date <= points[i].date {
            let (a, b) = (points[i - 1], points[i])
            let t = date.timeIntervalSince(a.date) / b.date.timeIntervalSince(a.date)
            return a.uvi + (b.uvi - a.uvi) * t
        }
        return last.uvi
    }
}

public enum LimitStage: Int, Comparable, Sendable {
    case none, approaching, reached
    public init(fraction: Double) { self = fraction >= 1 ? .reached : fraction >= 0.8 ? .approaching : .none }
    public static func < (a: LimitStage, b: LimitStage) -> Bool { a.rawValue < b.rawValue }
}

/// exposicion acumulada: minutos al aire libre (healthkit) x uv de esa hora (meteorologia).
public struct ExposureSummary: Sendable, Equatable {
    public let daylightMinutes: Double
    public let dose: Double
    public let fraction: Double
    public var stage: LimitStage { LimitStage(fraction: fraction) }

    /// `daylight`: minutos al aire libre por cubo de tiempo (inicio del cubo -> minutos).
    public static func build(daylight: [Date: Double], curve: UVCurve, skin: SkinType, protection: Double, bucket: TimeInterval = 3600) -> ExposureSummary {
        var minutes = 0.0
        var dose = 0.0
        for (start, m) in daylight where m > 0 {
            minutes += m
            dose += Exposure.dose(uvi: curve.uvi(at: start.addingTimeInterval(bucket / 2)), minutes: m, protection: protection)
        }
        return ExposureSummary(daylightMinutes: minutes, dose: dose, fraction: Exposure.fractionOfLimit(dose: dose, skin: skin))
    }
}
