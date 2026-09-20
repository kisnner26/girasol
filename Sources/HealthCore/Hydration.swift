import Foundation

public enum Hydration {
    /// meta orientativa: ~35 ml por kg, mas 300 ml si hace mucho calor. sin peso, 2000 ml. multiplo de 50.
    public static func suggestedGoalMl(weightKg: Double?, hot: Bool) -> Int {
        var ml = weightKg.map { min(3500, max(1500, $0 * 35)) } ?? 2000
        if hot { ml += 300 }
        return Int((ml / 50).rounded()) * 50
    }

    public static func glasses(ml: Int, glassMl: Int) -> Double {
        Double(ml) / Double(max(1, glassMl))
    }

    public static func fraction(consumedMl: Int, goalMl: Int) -> Double {
        Double(consumedMl) / Double(max(1, goalMl))
    }

    public struct Reminder: Equatable, Sendable {
        public let id: String
        public let date: Date
        public let title: String
        public let body: String
    }

    /// recordatorios de hoy: cada `everyHours` desde que despiertas hasta antes de dormir, solo los futuros,
    /// y ninguno si ya llegaste a la meta.
    public static func reminders(now: Date, calendar: Calendar, wakeHour: Int, sleepHour: Int, everyHours: Int,
                                 consumedMl: Int, goalMl: Int, glassMl: Int) -> [Reminder] {
        guard consumedMl < goalMl, everyHours >= 1 else { return [] }
        let remaining = goalMl - consumedMl
        let glassesLeft = Int((Double(remaining) / Double(max(1, glassMl))).rounded(.up))
        var out: [Reminder] = []
        var hour = wakeHour + everyHours
        while hour < sleepHour, out.count < 8 {
            if let d = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), d > now.addingTimeInterval(60) {
                out.append(.init(id: "girasol.water.\(hour)", date: d, title: "hora de tomar agua",
                                 body: glassesLeft == 1 ? "te falta 1 vaso para tu meta de hoy." : "te faltan \(glassesLeft) vasos para tu meta de hoy."))
            }
            hour += everyHours
        }
        return out
    }
}
