import XCTest
@testable import HealthCore

final class WeeklyTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private var today: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 15))! }

    private func record(daysAgo: Int, water: Int, steps: Int, waterGoal: Int = 2000, stepGoal: Int = 8000) -> DayRecord {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: today))!
        return DayRecord(day: day, waterMl: water, waterGoal: waterGoal, steps: steps, stepGoal: stepGoal)
    }

    func testTodayIsNotCountedBecauseTheDayIsStillRunning() {
        let s = WeeklySummary.make(records: [record(daysAgo: 0, water: 100, steps: 100)], today: today, calendar: cal)
        XCTAssertEqual(s.current.daysWithData, 0)
    }

    func testAveragesAndGoalDaysOverTheLastSevenFinishedDays() {
        let records = (1...7).map { record(daysAgo: $0, water: $0 <= 4 ? 2200 : 1000, steps: $0 <= 2 ? 9000 : 5000) }
        let s = WeeklySummary.make(records: records, today: today, calendar: cal)
        XCTAssertEqual(s.current.daysWithData, 7)
        XCTAssertEqual(s.current.waterGoalDays, 4)
        XCTAssertEqual(s.current.stepsGoalDays, 2)
        XCTAssertEqual(s.current.perfectDays, 2)
        XCTAssertEqual(s.current.avgWaterMl, (4 * 2200 + 3 * 1000) / 7)
    }

    func testPreviousWeekIsTheSevenDaysBefore() {
        let records = (1...7).map { record(daysAgo: $0, water: 2000, steps: 8000) } + (8...14).map { record(daysAgo: $0, water: 1000, steps: 4000) }
        let s = WeeklySummary.make(records: records, today: today, calendar: cal)
        XCTAssertEqual(s.previous.avgWaterMl, 1000)
        XCTAssertEqual(s.waterTrend, .up)
        XCTAssertEqual(s.stepsTrend, .up)
    }

    func testTrendIsUnknownWithoutAPreviousWeekAndSameWithinFivePercent() {
        let only = (1...7).map { record(daysAgo: $0, water: 2000, steps: 8000) }
        XCTAssertEqual(WeeklySummary.make(records: only, today: today, calendar: cal).waterTrend, .unknown)
        let near = only + (8...14).map { record(daysAgo: $0, water: 1950, steps: 8000) }
        XCTAssertEqual(WeeklySummary.make(records: near, today: today, calendar: cal).waterTrend, .same)
    }

    func testHighlightNeedsAtLeastThreeDays() {
        let s = WeeklySummary.make(records: (1...2).map { record(daysAgo: $0, water: 2500, steps: 9000) }, today: today, calendar: cal)
        XCTAssertEqual(s.highlight, .notEnoughData)
    }

    func testPerfectWeekNeedsEveryRecordedDayWithBothGoals() {
        let s = WeeklySummary.make(records: (1...6).map { record(daysAgo: $0, water: 2500, steps: 9000) }, today: today, calendar: cal)
        XCTAssertEqual(s.highlight, .perfectWeek)
    }

    func testHighlightPointsAtTheWeakerHabit() {
        let lowWater = (1...7).map { record(daysAgo: $0, water: 800, steps: 9000) }
        XCTAssertEqual(WeeklySummary.make(records: lowWater, today: today, calendar: cal).highlight, .needsWater)
        let lowSteps = (1...7).map { record(daysAgo: $0, water: 2500, steps: 2000) }
        XCTAssertEqual(WeeklySummary.make(records: lowSteps, today: today, calendar: cal).highlight, .needsSteps)
    }

    func testSleepAverageIgnoresEmptyNightsAndOtherWeeks() {
        let nights = [
            SleepNight(day: cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!, hours: 7),
            SleepNight(day: cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: today))!, hours: 5),
            SleepNight(day: cal.date(byAdding: .day, value: -3, to: cal.startOfDay(for: today))!, hours: 0),
            SleepNight(day: cal.date(byAdding: .day, value: -9, to: cal.startOfDay(for: today))!, hours: 9),
        ]
        let s = WeeklySummary.make(records: [], nights: nights, today: today, calendar: cal)
        XCTAssertEqual(s.current.avgSleepHours ?? 0, 6, accuracy: 0.001)
        XCTAssertEqual(s.previous.avgSleepHours ?? 0, 9, accuracy: 0.001)
    }
}
