import Foundation

/// un indice uv de 1 equivale a 0.025 w/m2 de irradiancia eritemica = 1.5 j/m2 por minuto.
public enum Exposure {
    public static let joulesPerMinutePerUVI = 1.5

    /// estimacion ambiental, no dosis medida en la piel. no aplica descuentos por spf.
    public static func dose(uvi: Double, minutes: Double) -> Double {
        guard uvi.isFinite, minutes.isFinite, uvi > 0, minutes > 0 else { return 0 }
        return uvi * joulesPerMinutePerUVI * minutes
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

/// exposicion acumulada: minutos al aire libre (healthkit) x uv de esa hora (meteorologia).
public struct ExposureSummary: Sendable, Equatable {
    public let daylightMinutes: Double
    public let dose: Double
    public let estimatedMinutes: Double
    /// cie: 1 sed = 100 j/m²; no representa una dosis segura.
    public var standardErythemaDoses: Double { dose / 100 }

    /// `daylight`: minutos al aire libre por cubo de tiempo (inicio del cubo -> minutos).
    public static func build(daylight: [Date: Double], curve: UVCurve, bucket: TimeInterval = 3600) -> ExposureSummary {
        var minutes = 0.0
        var dose = 0.0
        var estimatedMinutes = 0.0
        for (start, value) in daylight where value.isFinite && value > 0 {
            let m = min(value, max(0, bucket / 60))
            minutes += m
            guard let index = curve.points.firstIndex(where: { $0.date == start }),
                  curve.points[index].uvi.isFinite, curve.points[index].uvi >= 0 else { continue }
            let current = curve.points[index]
            let next = curve.points.dropFirst(index + 1).first
            let uv: Double
            if let next, next.date.timeIntervalSince(current.date) == bucket,
               next.uvi.isFinite, next.uvi >= 0 {
                uv = (current.uvi + next.uvi) / 2
            } else {
                uv = current.uvi
            }
            estimatedMinutes += m
            dose += Exposure.dose(uvi: uv, minutes: m)
        }
        return ExposureSummary(daylightMinutes: minutes, dose: dose, estimatedMinutes: estimatedMinutes)
    }
}
