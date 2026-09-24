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
    var nightsTwoWeeks: [SleepNight] = []
    var sleepInsight: SleepInsight?
    var standHours: [StandHour] = []

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
        totals = await health.today(now: now)
        heart = await health.heart()
        oxygen = await health.oxygen()
        loaded = true
        syncWidgets()
        await refreshHabits()
        await scheduleWaterReminders()
        await checkPosture()
    }

    /// racha y sueño: ultimos 7 dias de Salud.
    func refreshHabits() async {
        let today = now
        async let w = health.dailyWater(days: 7, now: today)
        async let s = health.dailySteps(days: 7, now: today)
        async let mindful = health.dailyMindful(days: 7, now: today)
        async let segments = health.sleep(days: 15, now: today)
        let (water, steps, mindfulMinutes, sleep) = await (w, s, mindful, segments)
        HabitStore.shared.merge(water: water, steps: steps, mindfulMinutes: mindfulMinutes, profile: profile)
        history = HabitStore.shared.records

        nights = Sleep.nights(sleep, today: today)
        nightsTwoWeeks = Sleep.nights(sleep, days: 14, today: today)
        sleepInsight = SleepInsight.make(nights.compactMap { n in
            guard let day = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: n.day) else { return nil }
            return (n, water[day] ?? 0, steps[day] ?? 0)
        })
    }

    var streak: Int { Streaks.current(history, today: now) }
    var bestStreak: Int { Streaks.best(history) }
    var lastNight: SleepNight? { nights.last(where: { $0.hours > 0 }) }

    var sedentaryHours: Int { Posture.consecutiveSedentaryHours(standHours, now: now) }

    /// esta semana contra la anterior: agua, pasos y sueño, sin sacar conclusiones de causa.
    var weeklyReport: WeeklyReport? { WeeklySummary.make(records: history, nights: nightsTwoWeeks, today: now) }

    /// llevas mucho rato sentado: consulta Salud y avisa si toca (una vez por bloque de horas).
    func checkPosture() async {
        guard profile.postureReminders else { return }
        standHours = await health.standHours(now: now)
        let hours = sedentaryHours
        if Posture.shouldRemind(consecutiveHours: hours, thresholdHours: profile.sedentaryThresholdHours) {
            await notifications.notifyPosture(consecutiveHours: hours, now: now)
        }
    }

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

    func logFocus(from start: Date, to end: Date) async {
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
