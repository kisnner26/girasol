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
        await scheduleWaterReminders()
    }

    func addWater(_ ml: Int) async {
        guard await health.addWater(ml: ml) else { return }
        totals.waterMl += ml
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
