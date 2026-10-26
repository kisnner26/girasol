import XCTest
@testable import HealthCore

final class TravelTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSmallShiftsAreIgnored() {
        XCTAssertNil(TravelMode.shiftHours(lastOffset: -21_600, currentOffset: -18_000))   // 1 h, horario de verano
        XCTAssertNil(TravelMode.shiftHours(lastOffset: 0, currentOffset: 7_200))
    }

    func testBigShiftsReportTheSignedHours() {
        XCTAssertEqual(TravelMode.shiftHours(lastOffset: -21_600, currentOffset: 3_600), 7)
        XCTAssertEqual(TravelMode.shiftHours(lastOffset: 3_600, currentOffset: -21_600), -7)
        XCTAssertEqual(TravelMode.shiftHours(lastOffset: 0, currentOffset: 10_800), 3)
    }

    func testBoostAddsTenPercentRoundedToFiftyAndRespectsTheCeiling() {
        XCTAssertEqual(TravelMode.boostedGoal(2000), 2200)
        XCTAssertEqual(TravelMode.boostedGoal(2150), 2350)
        XCTAssertEqual(TravelMode.boostedGoal(6000), 6000)
        XCTAssertEqual(TravelMode.boostedGoal(5800), 6000)
    }

    func testBoostLastsThreeFullDays() {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(b.originalGoalMl, 2000)
        XCTAssertEqual(b.boostedGoalMl, 2200)
        XCTAssertEqual(cal.dateComponents([.day], from: cal.startOfDay(for: now), to: b.until).day, 3)
    }

    func testBoostStaysActiveUntilItEnds() {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(TravelMode.outcome(b, currentGoalMl: 2200, now: now), .active)
    }

    func testFinishedBoostReturnsTheOriginalGoal() {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(TravelMode.outcome(b, currentGoalMl: 2200, now: b.until), .restore(2000))
    }

    func testFinishedBoostNeverOverwritesAGoalTheUserChanged() {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(TravelMode.outcome(b, currentGoalMl: 2500, now: b.until), .leaveGoal)
    }

    func testEndingEarlyRestoresBeforeTheDate() {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(TravelMode.outcome(b, currentGoalMl: 2200, now: now, endingEarly: true), .restore(2000))
    }

    func testBoostSurvivesEncoding() throws {
        let b = TravelMode.start(goalMl: 2000, now: now, calendar: cal)
        XCTAssertEqual(try JSONDecoder().decode(TravelMode.Boost.self, from: JSONEncoder().encode(b)), b)
    }
}
