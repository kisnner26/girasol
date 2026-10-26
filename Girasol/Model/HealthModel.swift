import Foundation
import Observation
import HealthCore

@MainActor
@Observable
final class HealthModel {
    let profiles = ProfileStore.shared
    private let health = HealthStore.shared
    private let notifications = NotificationService()

    var totals = TodayTotals()
    var heart = HeartInfo()
    var oxygen: [OxygenReading] = []
    var loaded = false
    var history: [DayRecord] = HabitStore.shared.records
    var nights: [SleepNight] = []
    var sleepInsight: SleepInsight?
    /// horas de cambio de zona horaria pendientes de responder; `nil` si no hay nada que proponer
    var travelShift: Int?
    var travel: TravelMode.Boost? = HealthModel.loadBoost()

    var profile: Profile { profiles.profile }
    var now: Date { Date() }

    // MARK: derivados

    var waterFraction: Double { Hydration.fraction(consumedMl: totals.waterMl, goalMl: profile.waterGoalMl) }
    var kcalFraction: Double { Nutrition.fraction(consumed: totals.foodKcal, goal: profile.kcalGoal) }
    var kcalRemaining: Int {
        Nutrition.remaining(goal: profile.kcalGoal, consumed: totals.foodKcal, active: totals.activeKcal, addActivity: profile.addActivityToKcal)
    }
    var stepsFraction: Double { totals.steps / Double(max(1, profile.stepGoal)) }
    var latestOxygen: OxygenReading? { oxygen.first }

    // MARK: acciones

    func refresh() async {
        checkTravel()
        totals = await health.today(now: now)
        heart = await health.heart()
        oxygen = await health.oxygen()
        loaded = true
        syncWidgets()
        await refreshHabits()
        await scheduleWaterReminders()
    }

    /// racha y sueño: ultimos 7 dias de Salud.
    func refreshHabits() async {
        let today = now
        async let w = health.dailyWater(days: 7, now: today)
        async let s = health.dailySteps(days: 7, now: today)
        async let segments = health.sleep(days: 8, now: today)
        let (water, steps, sleep) = await (w, s, segments)
        HabitStore.shared.merge(water: water, steps: steps, profile: profile)
        history = HabitStore.shared.records

        nights = Sleep.nights(sleep, today: today)
        sleepInsight = SleepInsight.make(nights.compactMap { n in
            guard let day = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: n.day) else { return nil }
            return (n, water[day] ?? 0, steps[day] ?? 0)
        })
    }

    // MARK: modo viaje

    private static let travelBoostKey = "girasol.travel.boost"
    private static let travelOffsetKey = "girasol.travel.offset"

    private static func loadBoost() -> TravelMode.Boost? {
        UserDefaults.standard.data(forKey: travelBoostKey).flatMap { try? JSONDecoder().decode(TravelMode.Boost.self, from: $0) }
    }

    private func rememberOffset() {
        UserDefaults.standard.set(TimeZone.current.secondsFromGMT(), forKey: Self.travelOffsetKey)
    }

    /// cierra el aumento si ya vencio y, si no hay uno en curso, mira si la zona horaria cambio lo bastante como para proponerlo.
    func checkTravel() {
        if let boost = travel {
            let outcome = TravelMode.outcome(boost, currentGoalMl: profile.waterGoalMl, now: now)
            if outcome != .active { finishTravel(outcome) }
        }
        guard travel == nil else { travelShift = nil; return }
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.travelOffsetKey) != nil else { rememberOffset(); return }
        travelShift = TravelMode.shiftHours(lastOffset: defaults.integer(forKey: Self.travelOffsetKey), currentOffset: TimeZone.current.secondsFromGMT())
    }

    func acceptTravel() async {
        guard travelShift != nil, travel == nil else { return }
        let boost = TravelMode.start(goalMl: profile.waterGoalMl, now: now)
        profiles.profile.waterGoalMl = boost.boostedGoalMl
        travel = boost
        if let data = try? JSONEncoder().encode(boost) { UserDefaults.standard.set(data, forKey: Self.travelBoostKey) }
        rememberOffset()
        travelShift = nil
        syncWidgets()
        Haptics.play(.success)
        await scheduleWaterReminders()
    }

    func dismissTravel() {
        rememberOffset()
        travelShift = nil
        Haptics.play(.click)
    }

    func endTravel() async {
        guard let boost = travel else { return }
        finishTravel(TravelMode.outcome(boost, currentGoalMl: profile.waterGoalMl, now: now, endingEarly: true))
        Haptics.play(.click)
        await scheduleWaterReminders()
    }

    private func finishTravel(_ outcome: TravelMode.Outcome) {
        if case .restore(let goal) = outcome { profiles.profile.waterGoalMl = goal }
        travel = nil
        UserDefaults.standard.removeObject(forKey: Self.travelBoostKey)
        rememberOffset()
        syncWidgets()
    }

    var streak: Int { Streaks.current(history, today: now) }
    var bestStreak: Int { Streaks.best(history) }
    var lastNight: SleepNight? { nights.last(where: { $0.hours > 0 }) }

    private func syncWidgets() {
        WidgetSync.totals(totals, profile: profile, kcalRemaining: kcalRemaining)
    }

    func addWater(_ ml: Int) async {
        guard await health.addWater(ml: ml) else { return }
        totals.waterMl += ml
        syncWidgets()
        Haptics.play(.success)
        await scheduleWaterReminders()
    }

    func undoWater() async {
        guard await health.undoLast(.water) else { Haptics.play(.failure); return }
        Haptics.play(.click)
        await refresh()
    }

    func addFood(_ kcal: Int) async {
        guard await health.addFood(kcal: Double(kcal)) else { return }
        totals.foodKcal += Double(kcal)
        syncWidgets()
        Haptics.play(.success)
    }

    func undoFood() async {
        guard await health.undoLast(.food) else { Haptics.play(.failure); return }
        Haptics.play(.click)
        await refresh()
    }

    func logBreathing(from start: Date, to end: Date) async {
        if await health.addMindful(start: start, end: end) { totals.mindfulMinutes += end.timeIntervalSince(start) / 60 }
    }

    func requestAccess() async { await health.requestAccess() }

    /// lee peso, estatura, edad y sexo de Salud y rellena lo que el usuario aun no puso.
    func importBody() async {
        let info = await health.body()
        var p = profile
        if p.weightKg == nil { p.weightKg = info.weightKg }
        if p.heightCm == nil { p.heightCm = info.heightCm }
        if p.birthYear == nil { p.birthYear = info.birthYear }
        if let s = info.sex, p.sex == .other { p.sex = s }
        profiles.profile = p
    }

    /// metas orientativas segun tus datos.
    func suggestedWaterGoal(hot: Bool = false) -> Int { Hydration.suggestedGoalMl(weightKg: profile.weightKg, hot: hot) }
    func suggestedKcalGoal() -> Int? { Nutrition.suggestedGoal(profile, year: Calendar.current.component(.year, from: now)) }

    func scheduleWaterReminders() async {
        let p = profile
        guard p.waterReminders else { await notifications.scheduleWater([]); return }
        let items = Hydration.reminders(now: now, calendar: .current, wakeHour: p.wakeHour, sleepHour: p.sleepHour,
                                        everyHours: p.reminderEveryHours, consumedMl: totals.waterMl, goalMl: p.waterGoalMl, glassMl: p.glassMl)
        await notifications.scheduleWater(items)
    }
}
