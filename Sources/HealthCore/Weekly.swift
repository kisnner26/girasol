import Foundation

/// resumen de la semana: los 7 dias ya terminados (sin contar hoy, que sigue en curso) frente a los 7 anteriores.
public struct WeeklySummary: Equatable, Sendable {
    public struct Stats: Equatable, Sendable {
        public let daysWithData: Int
        public let avgWaterMl: Int
        public let avgSteps: Int
        public let waterGoalDays: Int
        public let stepsGoalDays: Int
        public let perfectDays: Int
        public let avgSleepHours: Double?
    }

    public enum Trend: Equatable, Sendable { case up, down, same, unknown }

    /// lo que se destaca de la semana: un solo mensaje, el mas util y mas prudente que apoyan los datos
    public enum Highlight: Equatable, Sendable {
        case notEnoughData, perfectWeek, needsWater, needsSteps, waterUp, stepsUp, steady
    }

    public let current: Stats
    public let previous: Stats

    public var waterTrend: Trend { Self.trend(current.avgWaterMl, previous.avgWaterMl, current.daysWithData, previous.daysWithData) }
    public var stepsTrend: Trend { Self.trend(current.avgSteps, previous.avgSteps, current.daysWithData, previous.daysWithData) }

    public var highlight: Highlight {
        let n = current.daysWithData
        guard n >= 3 else { return .notEnoughData }
        if n >= 5, current.perfectDays == n { return .perfectWeek }
        let water = Double(current.waterGoalDays) / Double(n)
        let steps = Double(current.stepsGoalDays) / Double(n)
        if water < 0.5, water <= steps { return .needsWater }
        if steps < 0.5 { return .needsSteps }
        if waterTrend == .up { return .waterUp }
        if stepsTrend == .up { return .stepsUp }
        return .steady
    }

    public static func make(records: [DayRecord], nights: [SleepNight] = [], today: Date, calendar: Calendar = .current) -> WeeklySummary {
        let start = calendar.startOfDay(for: today)
        func window(_ from: Int, _ to: Int) -> Stats {
            guard let lo = calendar.date(byAdding: .day, value: -from, to: start),
                  let hi = calendar.date(byAdding: .day, value: -to, to: start) else { return empty }
            let days = records.filter { let d = calendar.startOfDay(for: $0.day); return d >= lo && d <= hi }
            let sleep = nights.filter { let d = calendar.startOfDay(for: $0.day); return d >= lo && d <= hi && $0.hours > 0 }
            let n = days.count
            return Stats(
                daysWithData: n,
                avgWaterMl: n == 0 ? 0 : days.reduce(0) { $0 + $1.waterMl } / n,
                avgSteps: n == 0 ? 0 : days.reduce(0) { $0 + $1.steps } / n,
                waterGoalDays: days.filter(\.waterMet).count,
                stepsGoalDays: days.filter(\.stepsMet).count,
                perfectDays: days.filter(\.allMet).count,
                avgSleepHours: sleep.isEmpty ? nil : sleep.reduce(0) { $0 + $1.hours } / Double(sleep.count))
        }
        return WeeklySummary(current: window(7, 1), previous: window(14, 8))
    }

    private static let empty = Stats(daysWithData: 0, avgWaterMl: 0, avgSteps: 0, waterGoalDays: 0, stepsGoalDays: 0, perfectDays: 0, avgSleepHours: nil)

    private static func trend(_ now: Int, _ before: Int, _ nowDays: Int, _ beforeDays: Int) -> Trend {
        guard nowDays > 0, beforeDays > 0, before > 0 else { return .unknown }
        let change = Double(now - before) / Double(before)
        return change > 0.05 ? .up : (change < -0.05 ? .down : .same)
    }
}
