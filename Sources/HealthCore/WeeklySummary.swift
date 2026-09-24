import Foundation

/// promedios diarios de esta semana contra los de la anterior: una comparacion, no una causa.
public struct WeeklyReport: Equatable, Sendable {
    public var waterMl: Int
    public var waterDeltaMl: Int          // esta semana menos la anterior; puede ser negativo
    public var steps: Int
    public var stepsDelta: Int
    public var sleepHours: Double
    public var sleepDeltaHours: Double
    public var hasSleepData: Bool
}

public enum WeeklySummary {
    /// hacen falta al menos `minDays` dias de registro en cada semana para no comparar con casi nada.
    public static func make(records: [DayRecord], nights: [SleepNight], today: Date, minDays: Int = 3, calendar: Calendar = .current) -> WeeklyReport? {
        let start = calendar.startOfDay(for: today)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: start),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -13, to: start),
              let dayBeforeWeekAgo = calendar.date(byAdding: .day, value: -1, to: weekAgo) else { return nil }

        let thisWeek = records.filter { let d = calendar.startOfDay(for: $0.day); return d >= weekAgo && d <= start }
        let lastWeek = records.filter { let d = calendar.startOfDay(for: $0.day); return d >= twoWeeksAgo && d <= dayBeforeWeekAgo }
        guard thisWeek.count >= minDays, lastWeek.count >= minDays else { return nil }

        func avg(_ xs: [DayRecord], _ f: (DayRecord) -> Int) -> Int { xs.map(f).reduce(0, +) / xs.count }
        func sleepAvg(inDays days: [Date]) -> Double? {
            let set = Set(days.map { calendar.startOfDay(for: $0) })
            let hs = nights.filter { set.contains(calendar.startOfDay(for: $0.day)) && $0.hours > 0 }.map(\.hours)
            return hs.isEmpty ? nil : hs.reduce(0, +) / Double(hs.count)
        }

        let water = avg(thisWeek, \.waterMl), waterPrev = avg(lastWeek, \.waterMl)
        let steps = avg(thisWeek, \.steps), stepsPrev = avg(lastWeek, \.steps)
        let sleep = sleepAvg(inDays: thisWeek.map(\.day)), sleepPrev = sleepAvg(inDays: lastWeek.map(\.day))

        return WeeklyReport(waterMl: water, waterDeltaMl: water - waterPrev, steps: steps, stepsDelta: steps - stepsPrev,
                            sleepHours: sleep ?? 0, sleepDeltaHours: (sleep ?? 0) - (sleepPrev ?? 0), hasSleepData: sleep != nil && sleepPrev != nil)
    }
}
