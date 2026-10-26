import Foundation

/// modo viaje: si cruzas varias zonas horarias, la app te propone subir un poco la meta de agua unos dias y despues la devuelve.
/// nunca cambia nada sin que lo aceptes, y si mientras tanto cambiaste la meta tu mismo, respeta tu valor.
public enum TravelMode {
    public static let minShiftSeconds = 3 * 3600
    public static let boostFraction = 0.10
    public static let durationDays = 3

    /// cambio de zona horaria en horas (con signo) si alcanza el umbral; `nil` si es menor.
    public static func shiftHours(lastOffset: Int, currentOffset: Int) -> Int? {
        let diff = currentOffset - lastOffset
        guard abs(diff) >= minShiftSeconds else { return nil }
        return Int((Double(diff) / 3600).rounded())
    }

    public struct Boost: Codable, Equatable, Sendable {
        public let originalGoalMl: Int
        public let boostedGoalMl: Int
        public let until: Date
    }

    /// meta subida un 10 %, redondeada a 50 ml y sin pasar del tope de 6000 ml del perfil.
    public static func boostedGoal(_ goalMl: Int) -> Int {
        let raw = Double(goalMl) * (1 + boostFraction)
        return min(6000, Int((raw / 50).rounded()) * 50)
    }

    public static func start(goalMl: Int, now: Date, calendar: Calendar = .current) -> Boost {
        let end = calendar.date(byAdding: .day, value: durationDays, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(Double(durationDays) * 86_400)
        return Boost(originalGoalMl: goalMl, boostedGoalMl: boostedGoal(goalMl), until: end)
    }

    public enum Outcome: Equatable, Sendable {
        /// sigue vigente
        case active
        /// terminado: devolver esta meta
        case restore(Int)
        /// terminado, pero el usuario ya habia cambiado la meta: no tocarla
        case leaveGoal
    }

    public static func outcome(_ boost: Boost, currentGoalMl: Int, now: Date, endingEarly: Bool = false) -> Outcome {
        guard endingEarly || now >= boost.until else { return .active }
        return currentGoalMl == boost.boostedGoalMl ? .restore(boost.originalGoalMl) : .leaveGoal
    }
}
