import Foundation
import HealthCore

/// historial diario para la racha: lo consumido cada dia (de Salud) y lo que llegaste a recibir de uv (lo mide la app).
/// vive en el reloj; solo se guardan los ultimos 60 dias.
@MainActor
final class HabitStore {
    static let shared = HabitStore()
    private let key = "girasol.habits"
    private(set) var records: [DayRecord]

    private init() {
        records = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([DayRecord].self, from: $0) } ?? []
    }

    /// combina lo leido de Salud con lo que ya habia guardado: las metas de dias pasados se conservan y el uv solo sube.
    func merge(water: [Date: Int], steps: [Date: Int], mindfulMinutes: [Date: Double] = [:], profile: Profile, calendar: Calendar = .current) {
        var byDay = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { _, new in new })
        for day in Set(water.keys).union(steps.keys).union(mindfulMinutes.keys) {
            var r = byDay[day] ?? DayRecord(day: day, waterMl: 0, waterGoal: profile.waterGoalMl, steps: 0, stepGoal: profile.stepGoal,
                                            mindfulGoal: Double(profile.mindfulGoalMinutes))
            r.waterMl = water[day] ?? r.waterMl
            r.steps = steps[day] ?? r.steps
            r.mindfulMinutes = mindfulMinutes[day] ?? r.mindfulMinutes
            if calendar.isDateInToday(day) {
                r.waterGoal = profile.waterGoalMl
                r.stepGoal = profile.stepGoal
                r.mindfulGoal = Double(profile.mindfulGoalMinutes)
            }
            byDay[day] = r
        }
        save(byDay)
    }

    /// guarda el uv mas alto del dia (solo tiene sentido para hoy: es cuando la app lo puede medir).
    func recordSun(fraction: Double, day: Date, profile: Profile) {
        var byDay = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { _, new in new })
        var r = byDay[day] ?? DayRecord(day: day, waterMl: 0, waterGoal: profile.waterGoalMl, steps: 0, stepGoal: profile.stepGoal)
        r.sunFraction = max(r.sunFraction ?? 0, fraction)
        byDay[day] = r
        save(byDay)
    }

    private func save(_ byDay: [Date: DayRecord]) {
        records = byDay.values.sorted { $0.day < $1.day }.suffix(60).map { $0 }
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) }
    }
}
