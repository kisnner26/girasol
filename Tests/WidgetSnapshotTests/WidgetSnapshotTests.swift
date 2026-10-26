import XCTest
@testable import WidgetSnapshotCore

final class WidgetSnapshotTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testCoverageDistinguishesNightFromMissingData() {
        var snapshot = WidgetSnapshot()
        XCTAssertNil(snapshot.uvi(at: start))
        snapshot.uv = [.init(start: start, uvi: 0)]
        XCTAssertEqual(snapshot.uvi(at: start), 0)
        XCTAssertTrue(snapshot.hasForecast(at: start.addingTimeInterval(3599)))
        XCTAssertNil(snapshot.uvi(at: start.addingTimeInterval(-1)))
        XCTAssertNil(snapshot.uvi(at: start.addingTimeInterval(3600)))
        XCTAssertFalse(snapshot.hasForecast(at: start.addingTimeInterval(86400)))
    }

    func testInterpolationAndUnsortedInput() {
        var snapshot = WidgetSnapshot()
        snapshot.uv = [.init(start: start.addingTimeInterval(3600), uvi: 6), .init(start: start, uvi: 2)]
        XCTAssertEqual(snapshot.uvi(at: start.addingTimeInterval(1800)), 4)
        XCTAssertEqual(snapshot.uvi(at: start.addingTimeInterval(3600)), 6)
        XCTAssertEqual(snapshot.uvi(at: start.addingTimeInterval(7199)), 6)
        XCTAssertNil(snapshot.uvi(at: start.addingTimeInterval(7200)))
    }

    func testMissingHoursDoNotInventUV() {
        var snapshot = WidgetSnapshot()
        snapshot.uv = [.init(start: start, uvi: 2), .init(start: start.addingTimeInterval(7200), uvi: 6)]
        XCTAssertNil(snapshot.uvi(at: start.addingTimeInterval(3600)))
        XCTAssertEqual(snapshot.uvi(at: start.addingTimeInterval(7200)), 6)
    }

    func testInvalidValuesAndOtherUpdatesCannotReviveForecast() {
        var snapshot = WidgetSnapshot()
        for invalid in [Double.nan, .infinity, -1] {
            snapshot.uv = [.init(start: start, uvi: invalid)]
            XCTAssertNil(snapshot.uvi(at: start))
        }
        snapshot.uv = [.init(start: start, uvi: 3)]
        snapshot.updated = start.addingTimeInterval(86400)
        snapshot.waterMl = 500
        XCTAssertNil(snapshot.uvi(at: snapshot.updated))
    }
}
