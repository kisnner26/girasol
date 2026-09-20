import Foundation

/// un tramo dormido (sin contar "en cama" ni "despierto").
public struct SleepSegment: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}

public struct SleepNight: Equatable, Sendable {
    public var day: Date        // el dia en que te despertaste
    public var hours: Double
    public init(day: Date, hours: Double) { self.day = day; self.hours = hours }
}

public enum Sleep {
    public static let goalHours = 7.0

    /// horas dormidas por noche. la noche de un dia es lo que termina entre las 18:00 del dia anterior y las 18:00 de ese dia;
    /// los tramos que se solapan (reloj y iphone) se cuentan una sola vez.
    public static func nights(_ segments: [SleepSegment], days: Int = 7, today: Date, calendar: Calendar = .current) -> [SleepNight] {
        let todayStart = calendar.startOfDay(for: today)
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: todayStart),
                  let windowEnd = calendar.date(byAdding: .hour, value: 18, to: day),
                  let windowStart = calendar.date(byAdding: .hour, value: -24, to: windowEnd) else { return nil }
            let inside = segments.filter { $0.end > windowStart && $0.end <= windowEnd }
            return SleepNight(day: day, hours: merged(inside).reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 3600)
        }
    }

    static func merged(_ segments: [SleepSegment]) -> [SleepSegment] {
        var out: [SleepSegment] = []
        for s in segments.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
            if var last = out.last, s.start <= last.end {
                last.end = max(last.end, s.end)
                out[out.count - 1] = last
            } else {
                out.append(s)
            }
        }
        return out
    }
}

/// compara los dias que dormiste bien con los que no.
public struct SleepInsight: Equatable, Sendable {
    public var restedDays: Int
    public var shortDays: Int
    public var waterDifferenceMl: Int     // dias descansados menos dias cortos
    public var stepsDifference: Int

    /// `nights` con lo bebido y los pasos del mismo dia. hace falta al menos 2 dias de cada lado para no inventar tendencias.
    public static func make(_ nights: [(night: SleepNight, waterMl: Int, steps: Int)], goal: Double = Sleep.goalHours) -> SleepInsight? {
        let valid = nights.filter { $0.night.hours > 0 }
        let rested = valid.filter { $0.night.hours >= goal }
        let short = valid.filter { $0.night.hours < goal }
        guard rested.count >= 2, short.count >= 2 else { return nil }
        func avg(_ xs: [(night: SleepNight, waterMl: Int, steps: Int)], _ f: ((night: SleepNight, waterMl: Int, steps: Int)) -> Int) -> Double {
            Double(xs.map(f).reduce(0, +)) / Double(xs.count)
        }
        return SleepInsight(restedDays: rested.count, shortDays: short.count,
                            waterDifferenceMl: Int((avg(rested, \.waterMl) - avg(short, \.waterMl)).rounded()),
                            stepsDifference: Int((avg(rested, \.steps) - avg(short, \.steps)).rounded()))
    }
}
