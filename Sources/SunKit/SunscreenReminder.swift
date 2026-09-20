import Foundation

/// recordatorio de reaplicar protector: un temporizador de 2 h desde la ultima aplicacion.
public struct SunscreenTimer: Codable, Equatable, Sendable {
    public static let interval: TimeInterval = 2 * 3600

    public let appliedAt: Date
    public init(appliedAt: Date) { self.appliedAt = appliedAt }

    public var due: Date { appliedAt.addingTimeInterval(Self.interval) }
    public func remaining(at now: Date) -> TimeInterval { max(0, due.timeIntervalSince(now)) }
    public func isActive(at now: Date) -> Bool { now < due }
}

public enum SunscreenReminder {
    /// minutos al aire libre en la ultima hora a partir de los cuales se considera que estas al sol.
    public static let outdoorMinutes = 15.0

    /// arranca solo el temporizador cuando el consejo pide protector, es de dia, llevas tiempo fuera y no hay uno en marcha.
    public static func shouldStart(advice: AdviceLevel, isDay: Bool, outdoorMinutesLastHour: Double, timer: SunscreenTimer?, now: Date) -> Bool {
        guard isDay, advice >= .care, outdoorMinutesLastHour >= outdoorMinutes else { return false }
        return !(timer?.isActive(at: now) ?? false)
    }

    /// minutos al aire libre en la hora anterior a `now`, a partir de los cubos por hora de healthkit
    /// (cada cubo aporta la parte que cae dentro de la ventana, suponiendo el minuto repartido de forma pareja).
    public static func outdoorMinutes(lastHourOf now: Date, buckets: [Date: Double], bucket: TimeInterval = 3600) -> Double {
        let from = now.addingTimeInterval(-3600)
        return buckets.reduce(0) { total, item in
            let (start, minutes) = item
            let end = start.addingTimeInterval(bucket)
            let overlap = min(end, now).timeIntervalSince(max(start, from))
            guard overlap > 0, bucket > 0 else { return total }
            return total + minutes * overlap / bucket
        }
    }
}
