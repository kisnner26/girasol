import XCTest
@testable import HealthCore

final class FocusTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var session: FocusSession { FocusSession(plan: .plan(id: "classic"), start: t0) }

    func testStartsFocusingWithFullTime() {
        let m = session.moment(at: t0)
        XCTAssertEqual(m.phase, .focus)
        XCTAssertEqual(m.round, 1)
        XCTAssertEqual(m.remaining, 1500, accuracy: 0.001)
        XCTAssertEqual(m.completedRounds, 0)
    }

    func testShortBreakFollowsFocusAndCountsTheRound() {
        let m = session.moment(at: t0.addingTimeInterval(1500))
        XCTAssertEqual(m.phase, .shortBreak)
        XCTAssertEqual(m.remaining, 300, accuracy: 0.001)
        XCTAssertEqual(m.round, 1)
        XCTAssertEqual(m.completedRounds, 1)
    }

    func testSecondRoundStartsAfterTheBreak() {
        let m = session.moment(at: t0.addingTimeInterval(1800))
        XCTAssertEqual(m.phase, .focus)
        XCTAssertEqual(m.round, 2)
        XCTAssertEqual(m.completedRounds, 1)
    }

    func testLongBreakComesAfterTheFourthRoundAndThenTheCycleRepeats() {
        // 4 enfoques de 25 + 3 descansos de 5 = 115 min
        let long = session.moment(at: t0.addingTimeInterval(115 * 60))
        XCTAssertEqual(long.phase, .longBreak)
        XCTAssertEqual(long.remaining, 900, accuracy: 0.001)
        XCTAssertEqual(long.completedRounds, 4)
        let again = session.moment(at: t0.addingTimeInterval((115 + 15) * 60))
        XCTAssertEqual(again.phase, .focus)
        XCTAssertEqual(again.round, 5)
        XCTAssertEqual(again.completedRounds, 4)
    }

    func testPausedTimeDoesNotCount() {
        let paused = session.pausing(at: t0.addingTimeInterval(600))
        XCTAssertTrue(paused.isPaused)
        XCTAssertEqual(paused.moment(at: t0.addingTimeInterval(5000)).remaining, 900, accuracy: 0.001)
        let resumed = paused.resuming(at: t0.addingTimeInterval(5000))
        XCTAssertFalse(resumed.isPaused)
        XCTAssertEqual(resumed.moment(at: t0.addingTimeInterval(5300)).remaining, 600, accuracy: 0.001)
    }

    func testSkipEndsTheCurrentPhaseNow() {
        let skipped = session.skipping(at: t0.addingTimeInterval(100))
        let m = skipped.moment(at: t0.addingTimeInterval(100))
        XCTAssertEqual(m.phase, .shortBreak)
        XCTAssertEqual(m.remaining, 300, accuracy: 0.001)
    }

    func testUpcomingTransitionsListThePhasesInOrder() {
        let list = session.upcomingTransitions(from: t0.addingTimeInterval(100), count: 3)
        XCTAssertEqual(list.map(\.phase), [.shortBreak, .focus, .shortBreak])
        XCTAssertEqual(list[0].date.timeIntervalSince(t0), 1500, accuracy: 0.001)
        XCTAssertEqual(list[1].date.timeIntervalSince(t0), 1800, accuracy: 0.001)
        XCTAssertEqual(list[2].date.timeIntervalSince(t0), 3300, accuracy: 0.001)
    }

    func testNoTransitionsWhilePaused() {
        XCTAssertTrue(session.pausing(at: t0).upcomingTransitions(from: t0, count: 3).isEmpty)
    }

    func testEveryPlanSurvivesEncodingAndDecoding() throws {
        for plan in FocusPlan.all {
            let original = FocusSession(plan: plan, start: t0).pausing(at: t0.addingTimeInterval(10))
            let decoded = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(original))
            XCTAssertEqual(decoded, original)
        }
    }
}
