import XCTest
@testable import HealthCore
import Localization

private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}
private func day(_ d: Int, hour: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 9, day: d, hour: hour))! }

private func rec(_ d: Int, water: Int = 2000, steps: Int = 8000, sun: Double? = nil) -> DayRecord {
    DayRecord(day: day(d, hour: 13), waterMl: water, waterGoal: 2000, steps: steps, stepGoal: 8000, sunFraction: sun)
}

final class StreakTests: XCTestCase {
    func testGoalsAreInclusive() {
        XCTAssertTrue(rec(1, water: 2000).waterMet); XCTAssertFalse(rec(1, water: 1999).waterMet)
        XCTAssertTrue(rec(1, steps: 8000).stepsMet); XCTAssertFalse(rec(1, steps: 7999).stepsMet)
    }

    func testSunLimitOnlyFailsWhenMeasuredAndExceeded() {
        XCTAssertTrue(rec(1, sun: nil).sunMet, "sin medicion no se castiga")
        XCTAssertTrue(rec(1, sun: 0.99).sunMet)
        XCTAssertFalse(rec(1, sun: 1.0).sunMet)
        XCTAssertFalse(rec(1, sun: 1.0).allMet)
    }

    func testAZeroGoalIsNeverMet() {
        XCTAssertFalse(DayRecord(day: day(1), waterMl: 0, waterGoal: 0, steps: 5, stepGoal: 5).waterMet)
    }

    func testCountsConsecutiveDaysEndingToday() {
        let r = [rec(18), rec(19), rec(20)]
        XCTAssertEqual(Streaks.current(r, today: day(20, hour: 15), calendar: cal), 3)
    }

    func testTodayNotYetMetDoesNotBreakTheStreak() {
        let r = [rec(18), rec(19), rec(20, water: 300)]
        XCTAssertEqual(Streaks.current(r, today: day(20, hour: 9), calendar: cal), 2)
    }

    func testAMissedDayBreaksIt() {
        let r = [rec(16), rec(17, water: 100), rec(18), rec(19), rec(20)]
        XCTAssertEqual(Streaks.current(r, today: day(20), calendar: cal), 3)
    }

    func testMissingRecordBreaksIt() {
        XCTAssertEqual(Streaks.current([rec(17), rec(19), rec(20)], today: day(20), calendar: cal), 2)
    }

    func testNothingMeansZero() {
        XCTAssertEqual(Streaks.current([], today: day(20), calendar: cal), 0)
        XCTAssertEqual(Streaks.current([rec(20, steps: 10)], today: day(20), calendar: cal), 0)
    }

    func testSunOverLimitBreaksTheStreak() {
        let r = [rec(18), rec(19, sun: 1.3), rec(20)]
        XCTAssertEqual(Streaks.current(r, today: day(20), calendar: cal), 1)
    }

    func testBestStreak() {
        let r = [rec(1), rec(2), rec(3), rec(5), rec(6), rec(7), rec(8), rec(9, water: 0), rec(10), rec(11)]
        XCTAssertEqual(Streaks.best(r, calendar: cal), 4)
        XCTAssertEqual(Streaks.best([], calendar: cal), 0)
        XCTAssertEqual(Streaks.best([rec(3)], calendar: cal), 1)
    }

    func testWeekHasSevenDaysOldestFirst() {
        let w = Streaks.week([rec(20), rec(16)], today: day(20, hour: 18), calendar: cal)
        XCTAssertEqual(w.count, 7)
        XCTAssertEqual(w.first?.day, day(14)); XCTAssertEqual(w.last?.day, day(20))
        XCTAssertNotNil(w[6].record); XCTAssertNotNil(w[2].record)
        XCTAssertNil(w[0].record); XCTAssertNil(w[5].record)
    }

    func testRecordsAreCodable() throws {
        let r = rec(20, sun: 0.5)
        XCTAssertEqual(try JSONDecoder().decode(DayRecord.self, from: JSONEncoder().encode(r)), r)
    }

    func testMindfulGoalOfZeroIsAlwaysMet() {
        XCTAssertTrue(DayRecord(day: day(1), waterMl: 2000, waterGoal: 2000, steps: 8000, stepGoal: 8000).mindfulMet)
        XCTAssertTrue(DayRecord(day: day(1), waterMl: 2000, waterGoal: 2000, steps: 8000, stepGoal: 8000).allMet)
    }

    func testMindfulGoalMustBeReached() {
        var r = DayRecord(day: day(1), waterMl: 2000, waterGoal: 2000, steps: 8000, stepGoal: 8000, mindfulMinutes: 4, mindfulGoal: 5)
        XCTAssertFalse(r.mindfulMet)
        XCTAssertFalse(r.allMet)
        r.mindfulMinutes = 5
        XCTAssertTrue(r.mindfulMet)
        XCTAssertTrue(r.allMet)
    }

    func testOldRecordsWithoutMindfulnessDecodeAsNotRequired() throws {
        // json guardado antes de que existiera mindfulness: sin esos campos
        let old = try JSONDecoder().decode(DayRecord.self, from: Data(#"{"day":0,"waterMl":2000,"waterGoal":2000,"steps":8000,"stepGoal":8000}"#.utf8))
        XCTAssertEqual(old.mindfulGoal, 0)
        XCTAssertTrue(old.mindfulMet)
        XCTAssertTrue(old.allMet)
    }
}

final class SleepTests: XCTestCase {
    private func seg(_ d1: Int, _ h1: Int, _ d2: Int, _ h2: Int) -> SleepSegment { SleepSegment(start: day(d1, hour: h1), end: day(d2, hour: h2)) }

    func testNightEndingInTheMorningBelongsToThatDay() {
        let n = Sleep.nights([seg(19, 23, 20, 7)], days: 1, today: day(20, hour: 10), calendar: cal)
        XCTAssertEqual(n.count, 1)
        XCTAssertEqual(n[0].day, day(20)); XCTAssertEqual(n[0].hours, 8, accuracy: 1e-9)
    }

    func testSplitSleepAddsUp() {
        let n = Sleep.nights([seg(19, 23, 20, 3), seg(20, 4, 20, 7)], days: 1, today: day(20, hour: 10), calendar: cal)
        XCTAssertEqual(n[0].hours, 7, accuracy: 1e-9)
    }

    func testOverlappingSourcesAreCountedOnce() {
        let n = Sleep.nights([seg(19, 23, 20, 7), seg(20, 1, 20, 6), seg(19, 22, 20, 0)], days: 1, today: day(20, hour: 10), calendar: cal)
        XCTAssertEqual(n[0].hours, 9, accuracy: 1e-9, "de 22:00 a 07:00")
    }

    func testAnAfternoonNapBelongsToTheNextNightWindowBoundary() {
        // 17:59 termina dentro de la ventana de hoy; 18:01 ya es de mañana
        let inside = Sleep.nights([SleepSegment(start: day(20, hour: 17), end: day(20, hour: 17).addingTimeInterval(3540))], days: 1, today: day(20, hour: 20), calendar: cal)
        XCTAssertEqual(inside[0].hours, 59.0 / 60, accuracy: 1e-9)
        let outside = Sleep.nights([SleepSegment(start: day(20, hour: 17), end: day(20, hour: 18).addingTimeInterval(60))], days: 1, today: day(20, hour: 20), calendar: cal)
        XCTAssertEqual(outside[0].hours, 0)
    }

    func testSevenNightsOldestFirst() {
        let n = Sleep.nights([seg(13, 23, 14, 7), seg(19, 23, 20, 6)], today: day(20, hour: 10), calendar: cal)
        XCTAssertEqual(n.count, 7)
        XCTAssertEqual(n.first?.day, day(14)); XCTAssertEqual(n.last?.day, day(20))
        XCTAssertEqual(n[0].hours, 8, accuracy: 1e-9); XCTAssertEqual(n[6].hours, 7, accuracy: 1e-9)
        XCTAssertEqual(n[3].hours, 0)
    }

    func testBackwardsSegmentsAreIgnored() {
        let n = Sleep.nights([SleepSegment(start: day(20, hour: 7), end: day(19, hour: 23))], days: 1, today: day(20, hour: 10), calendar: cal)
        XCTAssertEqual(n[0].hours, 0)
    }

    private func night(_ h: Double, water: Int, steps: Int) -> (night: SleepNight, waterMl: Int, steps: Int) {
        (SleepNight(day: day(1), hours: h), water, steps)
    }

    func testInsightComparesRestedAgainstShortNights() throws {
        let i = try XCTUnwrap(SleepInsight.make([night(8, water: 2200, steps: 9000), night(7, water: 2000, steps: 8000),
                                                 night(5, water: 1200, steps: 5000), night(6, water: 1400, steps: 6000)]))
        XCTAssertEqual(i.restedDays, 2); XCTAssertEqual(i.shortDays, 2)
        XCTAssertEqual(i.waterDifferenceMl, 800); XCTAssertEqual(i.stepsDifference, 3000)
    }

    func testInsightNeedsTwoOfEachAndIgnoresMissingNights() {
        XCTAssertNil(SleepInsight.make([night(8, water: 1, steps: 1), night(8, water: 1, steps: 1), night(5, water: 1, steps: 1)]))
        XCTAssertNil(SleepInsight.make([night(8, water: 1, steps: 1), night(8, water: 1, steps: 1), night(0, water: 1, steps: 1), night(0, water: 1, steps: 1)]))
        XCTAssertNotNil(SleepInsight.make([night(7, water: 1, steps: 1), night(7, water: 1, steps: 1), night(6.99, water: 1, steps: 1), night(6, water: 1, steps: 1)]), "7 h justas cuenta como descansado")
    }

    func testInsightCanBeNegative() throws {
        let i = try XCTUnwrap(SleepInsight.make([night(8, water: 1000, steps: 4000), night(8, water: 1000, steps: 4000),
                                                 night(5, water: 2000, steps: 9000), night(5, water: 2000, steps: 9000)]))
        XCTAssertEqual(i.waterDifferenceMl, -1000); XCTAssertEqual(i.stepsDifference, -5000)
    }
}

final class PostureTests: XCTestCase {
    private func stand(_ hour: Int, _ stood: Bool) -> StandHour { StandHour(hourStart: day(20, hour: hour), stood: stood) }

    func testCountsBackFromCurrentHourUntilStoodOrNoData() {
        let now = day(20, hour: 14).addingTimeInterval(30 * 60)
        let hours = [stand(11, true), stand(12, false), stand(13, false), stand(14, false)]
        XCTAssertEqual(Posture.consecutiveSedentaryHours(hours, now: now, calendar: cal), 3)
    }

    func testStandingResetsTheCount() {
        let now = day(20, hour: 14)
        let hours = [stand(12, false), stand(13, true), stand(14, false)]
        XCTAssertEqual(Posture.consecutiveSedentaryHours(hours, now: now, calendar: cal), 1)
    }

    func testMissingCurrentHourDataMeansZero() {
        let now = day(20, hour: 15)
        let hours = [stand(12, false), stand(13, false), stand(14, false)]
        XCTAssertEqual(Posture.consecutiveSedentaryHours(hours, now: now, calendar: cal), 0, "sin dato de la hora en curso no se asume nada")
    }

    func testStopsAtTheFirstHourWithoutData() {
        let now = day(20, hour: 14)
        let hours = [stand(14, false), stand(13, false)] // falta la de las 12
        XCTAssertEqual(Posture.consecutiveSedentaryHours(hours, now: now, calendar: cal), 2)
    }

    func testShouldRemindOnlyAtEachThresholdBlock() {
        XCTAssertFalse(Posture.shouldRemind(consecutiveHours: 1, thresholdHours: 2))
        XCTAssertTrue(Posture.shouldRemind(consecutiveHours: 2, thresholdHours: 2))
        XCTAssertFalse(Posture.shouldRemind(consecutiveHours: 3, thresholdHours: 2))
        XCTAssertTrue(Posture.shouldRemind(consecutiveHours: 4, thresholdHours: 2))
        XCTAssertFalse(Posture.shouldRemind(consecutiveHours: 0, thresholdHours: 2))
    }

    func testMessageText() {
        XCTAssertTrue(Posture.body(hours: 1).contains("1 hora"))
        XCTAssertTrue(Posture.body(hours: 2).contains("2 horas"))
    }
}

final class WeeklySummaryTests: XCTestCase {
    private func night(_ d: Int, _ h: Double) -> SleepNight { SleepNight(day: day(d), hours: h) }

    func testComparesThisWeekAgainstLastWeek() {
        // esta semana (15..20, 6 dias): agua 2500, pasos 9000; semana pasada (8..13, 6 dias): agua 2000, pasos 8000
        let thisWeek = (15...20).map { rec($0, water: 2500, steps: 9000) }
        let lastWeek = (8...13).map { rec($0, water: 2000, steps: 8000) }
        let report = try? XCTUnwrap(WeeklySummary.make(records: thisWeek + lastWeek, nights: [], today: day(20), calendar: cal))
        XCTAssertEqual(report?.waterMl, 2500)
        XCTAssertEqual(report?.waterDeltaMl, 500)
        XCTAssertEqual(report?.steps, 9000)
        XCTAssertEqual(report?.stepsDelta, 1000)
        XCTAssertFalse(report?.hasSleepData ?? true, "sin noches, sin dato de sueño")
    }

    func testIncludesSleepWhenBothWeeksHaveIt() throws {
        let thisWeek = (15...20).map { rec($0) }
        let lastWeek = (8...13).map { rec($0) }
        let nights = (15...20).map { night($0, 8) } + (8...13).map { night($0, 6) }
        let report = try XCTUnwrap(WeeklySummary.make(records: thisWeek + lastWeek, nights: nights, today: day(20), calendar: cal))
        XCTAssertTrue(report.hasSleepData)
        XCTAssertEqual(report.sleepHours, 8, accuracy: 1e-9)
        XCTAssertEqual(report.sleepDeltaHours, 2, accuracy: 1e-9)
    }

    func testNilWithoutEnoughDaysInEitherWeek() {
        let thisWeek = (18...20).map { rec($0) }      // solo 3 dias
        let lastWeek = (8...9).map { rec($0) }         // solo 2 dias: no alcanza
        XCTAssertNil(WeeklySummary.make(records: thisWeek + lastWeek, nights: [], today: day(20), calendar: cal))
        XCTAssertNotNil(WeeklySummary.make(records: thisWeek + lastWeek, nights: [], today: day(20), minDays: 2, calendar: cal))
    }

    func testNegativeDeltaWhenThingsGotWorse() {
        let thisWeek = (15...20).map { rec($0, water: 1800, steps: 6000) }
        let lastWeek = (8...13).map { rec($0, water: 2200, steps: 9000) }
        let report = try? XCTUnwrap(WeeklySummary.make(records: thisWeek + lastWeek, nights: [], today: day(20), calendar: cal))
        XCTAssertEqual(report?.waterDeltaMl, -400)
        XCTAssertEqual(report?.stepsDelta, -3000)
    }
}

final class TravelModeTests: XCTestCase {
    func testHourShift() {
        XCTAssertEqual(TravelMode.hourShift(fromOffsetSeconds: -21600, toOffsetSeconds: -21600), 0)
        XCTAssertEqual(TravelMode.hourShift(fromOffsetSeconds: -21600, toOffsetSeconds: 0), 6)
        XCTAssertEqual(TravelMode.hourShift(fromOffsetSeconds: 3600, toOffsetSeconds: -28800), -9)
    }

    func testIsTravelIgnoresDaylightSavingChanges() {
        XCTAssertFalse(TravelMode.isTravel(hourShift: 1))
        XCTAssertFalse(TravelMode.isTravel(hourShift: -1))
        XCTAssertFalse(TravelMode.isTravel(hourShift: 0))
        XCTAssertTrue(TravelMode.isTravel(hourShift: 2))
        XCTAssertTrue(TravelMode.isTravel(hourShift: -5))
    }

    func testShiftedHourWrapsAroundTheClock() {
        XCTAssertEqual(TravelMode.shiftedHour(8, by: 3), 11)
        XCTAssertEqual(TravelMode.shiftedHour(22, by: 3), 1)
        XCTAssertEqual(TravelMode.shiftedHour(2, by: -5), 21)
        XCTAssertEqual(TravelMode.shiftedHour(8, by: 0), 8)
        XCTAssertEqual(TravelMode.shiftedHour(0, by: -1), 23)
    }
}

final class LocalizationHookTests: XCTestCase {
    override func tearDown() { L10n.translate = { $0 } }

    func testWithoutATranslatorTheSpanishTextComesOutAsIs() {
        XCTAssertEqual(Objective.lose.title, "bajar de peso")
        XCTAssertEqual(L10n.tr("te faltan %d vasos para tu meta de hoy.", 3), "te faltan 3 vasos para tu meta de hoy.")
    }

    func testATranslatorIsUsedForPlainAndFormattedTextAndInModelTitles() {
        L10n.translate = { ["bajar de peso": "lose weight", "te faltan %d vasos para tu meta de hoy.": "you're %d glasses short of today's goal."][$0] ?? $0 }
        XCTAssertEqual(Objective.lose.title, "lose weight")
        XCTAssertEqual(Objective.gain.title, "subir de peso", "lo que no tiene traduccion queda en español")
        XCTAssertEqual(L10n.tr("te faltan %d vasos para tu meta de hoy.", 3), "you're 3 glasses short of today's goal.")
    }

    func testGreetingUsesTheTranslator() {
        L10n.translate = { $0 == "buenos días" ? "good morning" : $0 }
        XCTAssertEqual(Greeting.text(hour: 8, name: "Ana"), "good morning, Ana")
    }
}
