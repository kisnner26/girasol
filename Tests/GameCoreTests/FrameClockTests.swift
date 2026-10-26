import XCTest
@testable import GameCore

final class FrameClockTests: XCTestCase {
    func testResumeDoesNotConsumePausedTime() {
        var clock = FrameClock()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(clock.dt(start), 0)
        XCTAssertEqual(clock.dt(start.addingTimeInterval(0.02)), 0.02, accuracy: 0.00001)
        clock.reset()
        XCTAssertEqual(clock.dt(start.addingTimeInterval(600)), 0)
        XCTAssertEqual(clock.dt(start.addingTimeInterval(600.02)), 0.02, accuracy: 0.00001)
    }

    func testDelayedAndReversedTicksCannotJumpPhysics() {
        var clock = FrameClock()
        let start = Date(timeIntervalSince1970: 1000)
        _ = clock.dt(start)
        XCTAssertEqual(clock.dt(start.addingTimeInterval(100)), 0.05)
        XCTAssertEqual(clock.dt(start), 0)
    }
}
