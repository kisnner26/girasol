import XCTest
@testable import HealthCore

private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
private func at(_ h: Int, _ m: Int = 0, _ s: Int = 0) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: h, minute: m, second: s))!
}

final class ProfileTests: XCTestCase {
    func testSanitizedClampsEverything() {
        var p = Profile()
        p.waterGoalMl = 100; p.glassMl = 10; p.kcalGoal = 100; p.stepGoal = 10; p.reminderEveryHours = 0
        p.wakeHour = 0; p.sleepHour = 3; p.breathingMinutes = 99; p.heightCm = 10; p.weightKg = 900; p.mindfulGoalMinutes = -5
        let s = p.sanitized()
        XCTAssertEqual([s.waterGoalMl, s.glassMl, s.kcalGoal, s.stepGoal, s.reminderEveryHours], [500, 100, 800, 1000, 1])
        XCTAssertEqual(s.mindfulGoalMinutes, 0)
        XCTAssertEqual(s.wakeHour, 4)
        XCTAssertEqual(s.sleepHour, 10, "dormir al menos 6 h despues de despertar")
        XCTAssertEqual(s.breathingMinutes, 5)
        XCTAssertEqual(s.heightCm, 100)
        XCTAssertEqual(s.weightKg, 250)

        p.waterGoalMl = 99999; p.glassMl = 99999; p.kcalGoal = 99999; p.stepGoal = 999999; p.reminderEveryHours = 99
        p.wakeHour = 20; p.sleepHour = 30; p.breathingMinutes = 0; p.heightCm = 999; p.weightKg = 1; p.mindfulGoalMinutes = 999
        let t = p.sanitized()
        XCTAssertEqual(t.mindfulGoalMinutes, 60)
        XCTAssertEqual([t.waterGoalMl, t.glassMl, t.kcalGoal, t.stepGoal, t.reminderEveryHours], [6000, 1000, 6000, 40000, 6])
        XCTAssertEqual(t.wakeHour, 12)
        XCTAssertEqual(t.sleepHour, 23)
        XCTAssertEqual(t.breathingMinutes, 1)
        XCTAssertEqual(t.heightCm, 230)
        XCTAssertEqual(t.weightKg, 25)
    }

    func testSanitizedKeepsNilAndValidValues() {
        let p = Profile().sanitized()
        XCTAssertNil(p.heightCm)
        XCTAssertNil(p.weightKg)
        XCTAssertEqual(p, Profile().sanitized().sanitized(), "idempotente")
        XCTAssertEqual(p.waterGoalMl, 2000)
    }

    func testDisplayName() {
        var p = Profile()
        p.name = "  Kisnner  "
        XCTAssertEqual(p.displayName, "Kisnner")
        p.name = String(repeating: "a", count: 40)
        XCTAssertEqual(p.displayName.count, 20)
        p.name = "   "
        XCTAssertEqual(p.displayName, "")
    }

    func testJSONRoundTripAndForwardCompatibility() throws {
        var p = Profile()
        p.name = "Ana"; p.sex = .female; p.birthYear = 1995; p.weightKg = 60.5; p.objective = .lose
        p.volumeUnit = .oz; p.temperatureUnit = .fahrenheit; p.onboarded = true
        let back = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back, p)

        // datos guardados por una version vieja, con solo dos campos
        let old = try JSONDecoder().decode(Profile.self, from: Data(#"{"name":"Luis","waterGoalMl":2500}"#.utf8))
        XCTAssertEqual(old.name, "Luis")
        XCTAssertEqual(old.waterGoalMl, 2500)
        XCTAssertEqual(old.kcalGoal, Profile().kcalGoal, "lo que falta usa el valor por defecto")
        XCTAssertNil(old.birthYear)
        XCTAssertEqual(try JSONDecoder().decode(Profile.self, from: Data("{}".utf8)), Profile())
    }

    func testGreeting() {
        XCTAssertEqual(Greeting.text(hour: 4, name: ""), "buenas noches")
        XCTAssertEqual(Greeting.text(hour: 5, name: ""), "buenos días")
        XCTAssertEqual(Greeting.text(hour: 11, name: "Ana"), "buenos días, Ana")
        XCTAssertEqual(Greeting.text(hour: 12, name: " Ana "), "buenas tardes, Ana")
        XCTAssertEqual(Greeting.text(hour: 18, name: ""), "buenas tardes")
        XCTAssertEqual(Greeting.text(hour: 19, name: ""), "buenas noches")
        XCTAssertEqual(Greeting.text(hour: 23, name: ""), "buenas noches")
    }

    func testUnits() {
        XCTAssertEqual(VolumeUnit.ml.text(ml: 250), "250 ml")
        XCTAssertEqual(VolumeUnit.oz.text(ml: 250), "8 oz")
        XCTAssertEqual(VolumeUnit.oz.text(ml: 1000), "34 oz")
        XCTAssertEqual(TemperatureUnit.celsius.text(celsius: 29.6), "30°")
        XCTAssertEqual(TemperatureUnit.fahrenheit.text(celsius: 30), "86°")
        XCTAssertEqual(TemperatureUnit.fahrenheit.text(celsius: 0), "32°")
    }
}

final class HydrationTests: XCTestCase {
    func testSuggestedGoal() {
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: nil, hot: false), 2000)
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 70, hot: false), 2450)
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 73, hot: false), 2550, "se redondea a multiplos de 50")
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 100, hot: false), 3500, "tope")
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 30, hot: false), 1500, "piso")
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: 70, hot: true), 2750)
        XCTAssertEqual(Hydration.suggestedGoalMl(weightKg: nil, hot: true), 2300)
    }

    func testGlassesAndFraction() {
        XCTAssertEqual(Hydration.glasses(ml: 500, glassMl: 250), 2)
        XCTAssertEqual(Hydration.glasses(ml: 125, glassMl: 250), 0.5)
        XCTAssertEqual(Hydration.glasses(ml: 500, glassMl: 0), 500, "nunca divide entre cero")
        XCTAssertEqual(Hydration.fraction(consumedMl: 1000, goalMl: 2000), 0.5)
        XCTAssertEqual(Hydration.fraction(consumedMl: 3000, goalMl: 2000), 1.5)
    }

    private func plan(now: Date, consumed: Int = 0, goal: Int = 2000, every: Int = 2, wake: Int = 8, sleep: Int = 21) -> [Hydration.Reminder] {
        Hydration.reminders(now: now, calendar: utc, wakeHour: wake, sleepHour: sleep, everyHours: every, consumedMl: consumed, goalMl: goal, glassMl: 250)
    }

    func testRemindersAreFutureSlotsBeforeBedtime() {
        let r = plan(now: at(10, 30))
        XCTAssertEqual(r.map(\.date), [at(12), at(14), at(16), at(18), at(20)])
        XCTAssertEqual(r.map(\.id), ["girasol.water.12", "girasol.water.14", "girasol.water.16", "girasol.water.18", "girasol.water.20"])
        XCTAssertFalse(r.contains { $0.date >= at(21) }, "ninguno a la hora de dormir")
    }

    func testRemindersFromMorning() {
        XCTAssertEqual(plan(now: at(6)).map(\.date), [at(10), at(12), at(14), at(16), at(18), at(20)])
        XCTAssertEqual(plan(now: at(6), every: 3).map(\.date), [at(11), at(14), at(17), at(20)])
        XCTAssertEqual(plan(now: at(6), every: 1).count, 8, "tope de 8")
    }

    func testNoReminderAtBedtimeEvenWhenItLandsOnASlot() {
        // dormir a las 20 con recordatorios cada 2 h: el de las 20 no se programa
        XCTAssertEqual(plan(now: at(6), sleep: 20).map(\.date), [at(10), at(12), at(14), at(16), at(18)])
        XCTAssertEqual(plan(now: at(6), every: 3, sleep: 20).map(\.date), [at(11), at(14), at(17)])
    }

    func testNoRemindersWhenGoalReachedOrInvalid() {
        XCTAssertEqual(plan(now: at(6), consumed: 2000), [])
        XCTAssertEqual(plan(now: at(6), consumed: 5000), [])
        XCTAssertEqual(plan(now: at(6), every: 0), [])
        XCTAssertEqual(plan(now: at(22)), [])
    }

    func testReminderTextAndMarginBeforeSlot() {
        XCTAssertEqual(plan(now: at(6), consumed: 1750).first?.body, "te falta 1 vaso para tu meta de hoy.")
        XCTAssertEqual(plan(now: at(6), consumed: 0).first?.body, "te faltan 8 vasos para tu meta de hoy.")
        XCTAssertEqual(plan(now: at(6), consumed: 1600).first?.body, "te faltan 2 vasos para tu meta de hoy.", "400 ml = 1.6 vasos -> 2")
        // a menos de un minuto de la hora, ese recordatorio ya no se programa
        XCTAssertEqual(plan(now: at(11, 59, 30)).first?.date, at(14))
        XCTAssertEqual(plan(now: at(11, 58)).first?.date, at(12))
    }
}

final class NutritionTests: XCTestCase {
    func testBMR() {
        XCTAssertEqual(Nutrition.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 30), 1780, accuracy: 1e-9)
        XCTAssertEqual(Nutrition.bmr(sex: .female, weightKg: 60, heightCm: 165, age: 30), 1320.25, accuracy: 1e-9)
        XCTAssertEqual(Nutrition.bmr(sex: .other, weightKg: 80, heightCm: 180, age: 30), 1780 - 5 - 78, accuracy: 1e-9)
    }

    private func profile(_ o: Objective = .maintain, _ a: ActivityLevel = .light) -> Profile {
        var p = Profile()
        p.sex = .male; p.weightKg = 80; p.heightCm = 180; p.birthYear = 1996; p.objective = o; p.activity = a
        return p
    }

    func testSuggestedGoal() {
        XCTAssertEqual(Nutrition.suggestedGoal(profile(), year: 2026), 2450)        // 1780 * 1.375 = 2447.5
        XCTAssertEqual(Nutrition.suggestedGoal(profile(.lose), year: 2026), 1950)
        XCTAssertEqual(Nutrition.suggestedGoal(profile(.gain), year: 2026), 2750)
        XCTAssertEqual(Nutrition.suggestedGoal(profile(.maintain, .sedentary), year: 2026), 2150)   // 2136 -> 2150
    }

    func testSuggestedGoalNeedsData() {
        var p = profile()
        p.weightKg = nil
        XCTAssertNil(Nutrition.suggestedGoal(p, year: 2026))
        p = profile(); p.heightCm = nil
        XCTAssertNil(Nutrition.suggestedGoal(p, year: 2026))
        p = profile(); p.birthYear = nil
        XCTAssertNil(Nutrition.suggestedGoal(p, year: 2026))
    }

    func testSuggestedGoalClamps() {
        var small = Profile()
        small.sex = .female; small.weightKg = 45; small.heightCm = 150; small.birthYear = 1956; small.activity = .sedentary; small.objective = .lose
        XCTAssertEqual(Nutrition.suggestedGoal(small, year: 2026), 1200, "piso de seguridad")
        var big = Profile()
        big.sex = .male; big.weightKg = 200; big.heightCm = 200; big.birthYear = 2006; big.activity = .veryActive; big.objective = .gain
        XCTAssertEqual(Nutrition.suggestedGoal(big, year: 2026), 4500)
        var child = profile(); child.birthYear = 2026
        // edad minima de 10: 80 kg, 180 cm -> bmr 1880 x 1.375 = 2585 -> 2600 (con edad 0 saldria 2650)
        XCTAssertEqual(Nutrition.suggestedGoal(child, year: 2026), 2600)
    }

    func testRemainingAndFraction() {
        XCTAssertEqual(Nutrition.remaining(goal: 2000, consumed: 1500.4, active: 300, addActivity: false), 500)
        XCTAssertEqual(Nutrition.remaining(goal: 2000, consumed: 1500.4, active: 300, addActivity: true), 800)
        XCTAssertEqual(Nutrition.remaining(goal: 2000, consumed: 2300, active: 0, addActivity: false), -300)
        XCTAssertEqual(Nutrition.fraction(consumed: 1000, goal: 2000), 0.5)
        XCTAssertEqual(Nutrition.fraction(consumed: 100, goal: 0), 100, "meta 0 no divide entre cero")
    }
}

final class FocusTests: XCTestCase {
    private let classic = FocusPattern.pattern(id: "classic")
    private let short = FocusPattern.pattern(id: "short")

    func testPatterns() {
        XCTAssertEqual(classic.cycleMinutes, 30)
        XCTAssertEqual(short.cycleMinutes, 18)
        XCTAssertEqual(FocusPattern.pattern(id: "no-existe"), classic)
        XCTAssertEqual(FocusPattern.all.count, 3)
    }

    func testCyclesRoundToWholeBlocks() {
        XCTAssertEqual(FocusSession(pattern: classic, minutes: 30).cycles, 1)
        XCTAssertEqual(FocusSession(pattern: classic, minutes: 55).cycles, 2, "55/30 = 1.83 -> 2")
        XCTAssertEqual(FocusSession(pattern: classic, minutes: 0).cycles, 1, "minimo un ciclo")
        XCTAssertEqual(FocusSession(pattern: classic, minutes: 60).duration, 3600)
    }

    func testMomentsSwitchBetweenWorkAndRest() throws {
        let s = FocusSession(pattern: classic, minutes: 30)
        let start = try XCTUnwrap(s.moment(at: 0))
        XCTAssertEqual(start.phase, .work); XCTAssertEqual(start.phaseProgress, 0, accuracy: 1e-9); XCTAssertEqual(start.remaining, 1800)
        let midWork = try XCTUnwrap(s.moment(at: 750))   // mitad de los 25 min de trabajo
        XCTAssertEqual(midWork.phase, .work); XCTAssertEqual(midWork.phaseProgress, 0.5, accuracy: 1e-9)
        let rest = try XCTUnwrap(s.moment(at: 1500 + 60))   // 25 min + 1 min de descanso
        XCTAssertEqual(rest.phase, .rest); XCTAssertEqual(rest.phaseProgress, 60.0 / 300, accuracy: 1e-9)
        XCTAssertNil(s.moment(at: 1800))
        XCTAssertNil(s.moment(at: -1))
    }

    func testSecondCycleStartsAtWork() throws {
        let s = FocusSession(pattern: classic, minutes: 55)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 1800)).phase, .work)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 1800)).cycleIndex, 1)
    }

    func testHapticsOneWorkAndRestStartPerCycle() {
        let events = FocusSession(pattern: classic, minutes: 60).haptics()
        XCTAssertEqual(events.filter { $0.kind == .workStart }.count, 2)
        XCTAssertEqual(events.filter { $0.kind == .restStart }.count, 2)
        XCTAssertEqual(events.last, FocusHapticEvent(time: 3600, kind: .end))
        XCTAssertEqual(events.map(\.time), events.map(\.time).sorted())
    }

    func testNoRestHapticWhenBreakIsZero() {
        let zeroBreak = FocusPattern(id: "x", title: "x", detail: "x", workMinutes: 10, breakMinutes: 0)
        let events = FocusSession(pattern: zeroBreak, minutes: 10).haptics()
        XCTAssertEqual(events.filter { $0.kind == .restStart }.count, 0)
    }
}

final class VitalsTests: XCTestCase {
    func testOxygenLevels() {
        XCTAssertEqual(OxygenLevel(percent: 100), .normal)
        XCTAssertEqual(OxygenLevel(percent: 95), .normal)
        XCTAssertEqual(OxygenLevel(percent: 94.9), .watch)
        XCTAssertEqual(OxygenLevel(percent: 90), .watch)
        XCTAssertEqual(OxygenLevel(percent: 89.9), .low)
        XCTAssertTrue(OxygenLevel.normal < .watch && OxygenLevel.watch < .low)
        XCTAssertEqual(OxygenLevel.low.title, "baja")
        XCTAssertTrue(OxygenLevel.low.message.contains("médico"))
        XCTAssertFalse(OxygenLevel.normal.message.contains("médico"))
    }

    func testRestingHeart() {
        XCTAssertEqual(RestingHeart.title(bpm: 49.9), "baja")
        XCTAssertEqual(RestingHeart.title(bpm: 50), "normal")
        XCTAssertEqual(RestingHeart.title(bpm: 99.9), "normal")
        XCTAssertEqual(RestingHeart.title(bpm: 100), "alta en reposo")
    }
}

final class HeartVariabilityTests: XCTestCase {
    private var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ d: Int) -> Date { utc.date(from: DateComponents(year: 2026, month: 9, day: d))! }

    func testAveragesRecentAgainstPrevious() throws {
        // ultimos 7 dias (15..21): 40, 44, 48 ms; los 7 anteriores (8..14): 30, 34, 38 ms
        let samples = [(day(15), 40.0), (day(18), 44.0), (day(21), 48.0), (day(8), 30.0), (day(11), 34.0), (day(14), 38.0)]
            .map { (date: $0.0, sdnnMs: $0.1) }
        let t = try XCTUnwrap(HeartVariability.trend(samples: samples, today: day(21), calendar: utc))
        XCTAssertEqual(t.recentAvgMs, 44, accuracy: 1e-9)
        XCTAssertEqual(t.previousAvgMs, 34, accuracy: 1e-9)
        XCTAssertEqual(t.deltaMs, 10, accuracy: 1e-9)
    }

    func testNilWithoutSamplesOnEitherSide() {
        let onlyRecent = [(date: day(20), sdnnMs: 40.0)]
        XCTAssertNil(HeartVariability.trend(samples: onlyRecent, today: day(21), calendar: utc))
        XCTAssertNil(HeartVariability.trend(samples: [], today: day(21), calendar: utc))
    }

    func testNegativeDeltaWhenHRVDropped() throws {
        let samples = [(date: day(20), sdnnMs: 30.0), (date: day(10), sdnnMs: 50.0)]
        let t = try XCTUnwrap(HeartVariability.trend(samples: samples, today: day(21), calendar: utc))
        XCTAssertEqual(t.deltaMs, -20, accuracy: 1e-9)
    }

    func testSamplesOutsideBothWindowsAreIgnored() throws {
        let samples = [(date: day(20), sdnnMs: 40.0), (date: day(12), sdnnMs: 30.0), (date: day(1), sdnnMs: 999.0)]
        let t = try XCTUnwrap(HeartVariability.trend(samples: samples, today: day(21), calendar: utc))
        XCTAssertEqual(t.recentAvgMs, 40, accuracy: 1e-9)
        XCTAssertEqual(t.previousAvgMs, 30, accuracy: 1e-9)
    }
}

final class BreathingTests: XCTestCase {
    private let calm = BreathingPattern.pattern(id: "calm")
    private let box = BreathingPattern.pattern(id: "box")
    private let sleep = BreathingPattern.pattern(id: "sleep")

    func testPatterns() {
        XCTAssertEqual(calm.cycle, 10)
        XCTAssertEqual(box.cycle, 16)
        XCTAssertEqual(sleep.cycle, 19)
        XCTAssertEqual(BreathingPattern.pattern(id: "no-existe"), calm, "id desconocido: el suave")
        XCTAssertEqual(BreathingPattern.all.count, 3)
    }

    func testCyclesRoundToWholeBreaths() {
        XCTAssertEqual(BreathingSession(pattern: calm, minutes: 1).cycles, 6)
        XCTAssertEqual(BreathingSession(pattern: calm, minutes: 1).duration, 60)
        XCTAssertEqual(BreathingSession(pattern: box, minutes: 1).cycles, 4)     // 3.75
        XCTAssertEqual(BreathingSession(pattern: box, minutes: 1).duration, 64)
        XCTAssertEqual(BreathingSession(pattern: sleep, minutes: 1).cycles, 3)   // 3.16
        XCTAssertEqual(BreathingSession(pattern: calm, minutes: 3).cycles, 18)
        XCTAssertEqual(BreathingSession(pattern: sleep, minutes: 0).cycles, 1, "minimo un ciclo")
    }

    func testMomentsAndScale() throws {
        let s = BreathingSession(pattern: calm, minutes: 1)
        let m0 = try XCTUnwrap(s.moment(at: 0))
        XCTAssertEqual(m0.phase, .inhale); XCTAssertEqual(m0.scale, 0, accuracy: 1e-9); XCTAssertEqual(m0.remaining, 60)
        let m2 = try XCTUnwrap(s.moment(at: 2))
        XCTAssertEqual(m2.phaseProgress, 0.5, accuracy: 1e-9); XCTAssertEqual(m2.scale, 0.5, accuracy: 1e-9)
        let m4 = try XCTUnwrap(s.moment(at: 4))
        XCTAssertEqual(m4.phase, .exhale); XCTAssertEqual(m4.scale, 1, accuracy: 1e-9)
        let m7 = try XCTUnwrap(s.moment(at: 7))
        XCTAssertEqual(m7.scale, 0.5, accuracy: 1e-9)
        let m10 = try XCTUnwrap(s.moment(at: 10))
        XCTAssertEqual(m10.phase, .inhale); XCTAssertEqual(m10.cycleIndex, 1)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 59.99)).cycleIndex, 5)
        XCTAssertNil(s.moment(at: 60))
        XCTAssertNil(s.moment(at: -1))
    }

    func testEasingIsSmoothNotLinear() throws {
        let s = BreathingSession(pattern: calm, minutes: 1)
        // suavizado: a un cuarto de la fase la flor va mas lenta que en linea recta (0.15625, no 0.25)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 1)).scale, 0.15625, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 3)).scale, 0.84375, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 5.5)).scale, 0.84375, accuracy: 1e-9)   // exhalando: 1 - 0.15625
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 8.5)).scale, 0.15625, accuracy: 1e-9)
    }

    func testHoldsInBoxPattern() throws {
        let s = BreathingSession(pattern: box, minutes: 1)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 5)).phase, .holdIn)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 5)).scale, 1)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 9)).phase, .exhale)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 13)).phase, .holdOut)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 13)).scale, 0)
        XCTAssertEqual(try XCTUnwrap(s.moment(at: 16)).phase, .inhale)
    }

    func testScaleIsMonotonicWithinPhases() throws {
        let s = BreathingSession(pattern: calm, minutes: 1)
        var last = -1.0
        for i in 0..<40 { let m = try XCTUnwrap(s.moment(at: Double(i) * 0.1)); XCTAssertGreaterThanOrEqual(m.scale, last); last = m.scale }
        last = 2
        for i in 40..<100 { let m = try XCTUnwrap(s.moment(at: Double(i) * 0.1)); XCTAssertLessThanOrEqual(m.scale, last); last = m.scale }
    }

    func testHapticsForCalm() {
        let one = BreathingSession(pattern: calm, minutes: 1).haptics()
        let starts = one.filter { $0.kind == .inhaleStart }.count, exhales = one.filter { $0.kind == .exhaleStart }.count
        XCTAssertEqual(starts, 6); XCTAssertEqual(exhales, 6)
        // por ciclo: inhale (1 + 3 toques) + exhale (1 + 5 toques) = 10; mas el final
        XCTAssertEqual(one.count, 6 * 10 + 1)
        XCTAssertEqual(one.last, HapticEvent(time: 60, kind: .end))
        XCTAssertEqual(one.map(\.time), one.map(\.time).sorted())
        XCTAssertEqual(one[0], HapticEvent(time: 0, kind: .inhaleStart))
        XCTAssertEqual(one[1], HapticEvent(time: 1, kind: .tick))
        XCTAssertEqual(one[4], HapticEvent(time: 4, kind: .exhaleStart))
    }

    func testHapticsForHoldPatterns() {
        let b = BreathingSession(pattern: box, minutes: 1).haptics()
        XCTAssertEqual(b.filter { $0.kind == .hold }.count, 4 * 2, "una pausa tras inhalar y otra tras exhalar, por ciclo")
        let s = BreathingSession(pattern: sleep, minutes: 1).haptics()
        XCTAssertEqual(s.filter { $0.kind == .hold }.count, 3, "4-7-8 solo sostiene tras inhalar")
        XCTAssertEqual(s.last?.time, 57)
        XCTAssertTrue(b.allSatisfy { $0.time <= 64 })
    }
}
