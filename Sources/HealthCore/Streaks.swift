import Foundation

/// lo que paso en un dia: lo consumido y las metas que tenias entonces.
public struct DayRecord: Codable, Equatable, Sendable {
    public var day: Date              // inicio del dia
    public var waterMl: Int
    public var waterGoal: Int
    public var steps: Int
    public var stepGoal: Int
    /// fraccion de tu limite de uv que llegaste a recibir ese dia; nil si la app no llego a medirlo.
    public var sunFraction: Double?

    public init(day: Date, waterMl: Int, waterGoal: Int, steps: Int, stepGoal: Int, sunFraction: Double? = nil) {
        self.day = day; self.waterMl = waterMl; self.waterGoal = waterGoal
        self.steps = steps; self.stepGoal = stepGoal; self.sunFraction = sunFraction
    }

    public var waterMet: Bool { waterGoal > 0 && waterMl >= waterGoal }
    public var stepsMet: Bool { stepGoal > 0 && steps >= stepGoal }
    /// sin dato de uv no se castiga: solo cuenta como fallo si se midio y pasaste tu limite.
    public var sunMet: Bool { (sunFraction ?? 0) < 1 }
    public var allMet: Bool { waterMet && stepsMet && sunMet }
}

public enum Streaks {
    /// dias seguidos con las tres metas cumplidas. hoy suma si ya cumpliste, pero no rompe la racha mientras el dia sigue.
    public static func current(_ records: [DayRecord], today: Date, calendar: Calendar = .current) -> Int {
        let byDay = index(records, calendar)
        let start = calendar.startOfDay(for: today)
        var cursor = start
        var count = 0
        if byDay[start]?.allMet == true { count += 1 }
        while let prev = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = prev
            guard byDay[cursor]?.allMet == true else { break }
            count += 1
        }
        return count
    }

    /// la racha mas larga que aparece en los registros.
    public static func best(_ records: [DayRecord], calendar: Calendar = .current) -> Int {
        let days = Set(records.filter(\.allMet).map { calendar.startOfDay(for: $0.day) })
        var best = 0
        for d in days {
            // solo empieza a contar en el primer dia de cada racha
            if let prev = calendar.date(byAdding: .day, value: -1, to: d), days.contains(prev) { continue }
            var run = 0
            var cursor = d
            while days.contains(cursor) {
                run += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            best = max(best, run)
        }
        return best
    }

    /// los ultimos 7 dias, del mas antiguo al de hoy; `nil` donde no hay registro.
    public static func week(_ records: [DayRecord], today: Date, calendar: Calendar = .current) -> [(day: Date, record: DayRecord?)] {
        let byDay = index(records, calendar)
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: start).map { ($0, byDay[$0]) }
        }
    }

    private static func index(_ records: [DayRecord], _ calendar: Calendar) -> [Date: DayRecord] {
        Dictionary(records.map { (calendar.startOfDay(for: $0.day), $0) }, uniquingKeysWith: { _, new in new })
    }
}
