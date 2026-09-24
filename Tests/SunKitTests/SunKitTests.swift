import XCTest
@testable import SunKit

private let utc = TimeZone(secondsFromGMT: 0)!

private func date(_ hhmm: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = utc; f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: "2026-09-20 \(hhmm)")!
}

private func hours(_ uv: [(String, Double)]) -> [WeatherSnapshot.Hour] {
    uv.map { .init(start: date($0.0), uvIndex: $0.1, temperature: 30, apparentTemperature: 32) }
}

private func fixture() throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "managua", withExtension: "json", subdirectory: "Fixtures")!)
}

final class UVTests: XCTestCase {
    func testCategoryBoundaries() {
        let cases: [(Double, UVCategory)] = [(0, .low), (2.99, .low), (3, .moderate), (5.99, .moderate), (6, .high),
                                             (7.99, .high), (8, .veryHigh), (10.99, .veryHigh), (11, .extreme), (14, .extreme)]
        for (uvi, cat) in cases { XCTAssertEqual(UVCategory(uvi: uvi), cat, "uvi \(uvi)") }
        XCTAssertTrue(UVCategory.low < .extreme)
    }

    func testSunscreenFactor() {
        XCTAssertEqual(Sunscreen.none.protectionFactor, 1)
        XCTAssertEqual(Sunscreen(spf: 15).protectionFactor, 7.5)
        XCTAssertEqual(Sunscreen(spf: 30).protectionFactor, 15)
        XCTAssertEqual(Sunscreen(spf: 50).protectionFactor, 25)
        XCTAssertEqual(Sunscreen(spf: 1).protectionFactor, 1, "nunca menos que sin protector")
    }
}

final class ExposureTests: XCTestCase {
    func testDoseKnownValue() {
        // uv 8 durante 25 min = 300 j/m2 = la med del tipo iii
        XCTAssertEqual(Exposure.dose(uvi: 8, minutes: 25), 300, accuracy: 1e-9)
        XCTAssertEqual(Exposure.fractionOfLimit(dose: 300, skin: .iii), 1, accuracy: 1e-9)
        XCTAssertEqual(Exposure.fractionOfLimit(dose: 300, skin: .i), 1.5, accuracy: 1e-9)
    }

    func testDoseIgnoresNothingAndProtects() {
        XCTAssertEqual(Exposure.dose(uvi: 0, minutes: 60), 0)
        XCTAssertEqual(Exposure.dose(uvi: 8, minutes: 0), 0)
        XCTAssertEqual(Exposure.dose(uvi: 8, minutes: 25, protection: 15), 20, accuracy: 1e-9)
        XCTAssertEqual(Exposure.dose(uvi: 8, minutes: 25, protection: 0.3), 300, accuracy: 1e-9, "el factor nunca amplifica")
    }

    func testMinutesToLimit() throws {
        XCTAssertEqual(try XCTUnwrap(Exposure.minutesToLimit(uvi: 8, usedFraction: 0, skin: .iii)), 25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(Exposure.minutesToLimit(uvi: 8, usedFraction: 0.5, skin: .iii)), 12.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(Exposure.minutesToLimit(uvi: 8, usedFraction: 0, skin: .iii, protection: 15)), 375, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(Exposure.minutesToLimit(uvi: 8, usedFraction: 0, skin: .vi)), 75, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(Exposure.minutesToLimit(uvi: 8, usedFraction: 1.4, skin: .iii)), 0)
        XCTAssertNil(Exposure.minutesToLimit(uvi: 0.4, usedFraction: 0, skin: .iii), "uv casi nulo: sin limite practico")
    }

    func testCurveInterpolation() {
        let c = UVCurve(hours: hours([("11:00", 4), ("12:00", 8), ("13:00", 6)]))
        XCTAssertEqual(c.uvi(at: date("12:00")), 8, accuracy: 1e-9)
        XCTAssertEqual(c.uvi(at: date("11:30")), 6, accuracy: 1e-9)
        XCTAssertEqual(c.uvi(at: date("12:30")), 7, accuracy: 1e-9)
        XCTAssertEqual(c.uvi(at: date("09:00")), 4, "antes del primer punto: se mantiene")
        XCTAssertEqual(c.uvi(at: date("18:00")), 6, "despues del ultimo: se mantiene")
        XCTAssertEqual(UVCurve(hours: []).uvi(at: date("12:00")), 0)
    }

    func testCurveSortsInput() {
        let c = UVCurve(hours: hours([("13:00", 6), ("11:00", 4), ("12:00", 8)]))
        XCTAssertEqual(c.uvi(at: date("11:30")), 6, accuracy: 1e-9)
    }

    func testSummaryAccumulatesByHour() {
        let curve = UVCurve(hours: hours([("11:00", 6), ("12:00", 8), ("13:00", 8), ("14:00", 6)]))
        // 30 min en la hora de las 12 (uv 8 a mitad de hora) + 60 min en la de las 13
        let s = ExposureSummary.build(daylight: [date("12:00"): 30, date("13:00"): 60, date("09:00"): 0],
                                      curve: curve, skin: .iii, protection: 1)
        XCTAssertEqual(s.daylightMinutes, 90)
        let expected = 8 * 1.5 * 30 + 7 * 1.5 * 60   // 12:30 -> uv 8, 13:30 -> uv 7
        XCTAssertEqual(s.dose, expected, accuracy: 1e-9)
        XCTAssertEqual(s.fraction, expected / 300, accuracy: 1e-9)
        XCTAssertEqual(s.stage, .reached)
    }

    func testSummaryProtectionAndEmpty() {
        let curve = UVCurve(hours: hours([("12:00", 8), ("13:00", 8)]))
        let sp = ExposureSummary.build(daylight: [date("12:00"): 30], curve: curve, skin: .iii, protection: 15)
        XCTAssertEqual(sp.dose, 24, accuracy: 1e-9)
        XCTAssertEqual(sp.stage, .none)
        let none = ExposureSummary.build(daylight: [:], curve: curve, skin: .iii, protection: 1)
        XCTAssertEqual(none.fraction, 0)
        XCTAssertEqual(none.daylightMinutes, 0)
    }

    func testLimitStage() {
        XCTAssertEqual(LimitStage(fraction: 0), .none)
        XCTAssertEqual(LimitStage(fraction: 0.79), .none)
        XCTAssertEqual(LimitStage(fraction: 0.8), .approaching)
        XCTAssertEqual(LimitStage(fraction: 0.99), .approaching)
        XCTAssertEqual(LimitStage(fraction: 1), .reached)
        XCTAssertTrue(LimitStage.none < .approaching && LimitStage.approaching < .reached)
    }
}

final class WeatherTests: XCTestCase {
    func testURLRoundsCoordinatesForPrivacy() {
        let u = OpenMeteo.url(latitude: 12.126537, longitude: -86.196045).absoluteString
        XCTAssertTrue(u.contains("latitude=12.13"), u)
        XCTAssertTrue(u.contains("longitude=-86.20"), u)
        XCTAssertFalse(u.contains("12.126"))
        XCTAssertTrue(u.contains("timezone=auto"))
        XCTAssertTrue(u.contains("uv_index"))
    }

    func testDecodeRealResponse() throws {
        let s = try OpenMeteo.decode(fixture(), fetchedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(s.utcOffset, -21600)
        XCTAssertEqual(s.hours.count, 24)
        XCTAssertEqual(s.current.temperature, 29.0)
        XCTAssertEqual(s.current.apparentTemperature, 35.6)
        XCTAssertEqual(s.current.uvIndex, 1.55)
        XCTAssertEqual(s.current.cloudCover, 55)
        XCTAssertTrue(s.current.isDay)
        // 10:45 hora de managua = 16:45 utc
        XCTAssertEqual(s.current.time, date("16:45"))
        // 00:00 local = 06:00 utc; el uv de las 12:00 local es 2.3
        XCTAssertEqual(s.hours[0].start, date("06:00"))
        XCTAssertEqual(s.hours[12].uvIndex, 2.3)
        XCTAssertEqual(s.hours.map(\.uvIndex).max(), 2.45)
        XCTAssertEqual(s.timeZone.secondsFromGMT(), -21600)
    }

    func testDecodeSkipsHolesInsteadOfInventingData() throws {
        let json = """
        {"utc_offset_seconds":0,"current":{"time":"2026-09-20T10:00","temperature_2m":20,"apparent_temperature":21,"uv_index":2,"cloud_cover":0,"is_day":1},
         "hourly":{"time":["2026-09-20T10:00","2026-09-20T11:00","2026-09-20T12:00"],"uv_index":[1,null,3],"temperature_2m":[20,21,22],"apparent_temperature":[null,22,23]}}
        """
        let s = try OpenMeteo.decode(Data(json.utf8))
        XCTAssertEqual(s.hours.map(\.uvIndex), [1, 3])
        XCTAssertEqual(s.hours[0].apparentTemperature, 20, "sin sensacion termica: se usa la temperatura")
    }

    func testDecodeSkipsHourWithoutTemperature() throws {
        let json = """
        {"utc_offset_seconds":0,"current":{"time":"2026-09-20T10:00","temperature_2m":20,"apparent_temperature":21,"uv_index":2,"cloud_cover":0,"is_day":1},
         "hourly":{"time":["2026-09-20T10:00","2026-09-20T11:00"],"uv_index":[1,5],"temperature_2m":[20,null],"apparent_temperature":[20,20]}}
        """
        let s = try OpenMeteo.decode(Data(json.utf8))
        XCTAssertEqual(s.hours.map(\.uvIndex), [1], "sin temperatura no se rellena con 0")
    }

    func testDecodeRejectsGarbage() {
        XCTAssertThrowsError(try OpenMeteo.decode(Data("nada".utf8)))
        XCTAssertThrowsError(try OpenMeteo.decode(Data(#"{"utc_offset_seconds":0,"current":{"time":"x","temperature_2m":1,"apparent_temperature":1,"uv_index":1,"cloud_cover":1,"is_day":1},"hourly":{"time":[],"uv_index":[],"temperature_2m":[],"apparent_temperature":[]}}"#.utf8)))
    }
}

final class AdviceTests: XCTestCase {
    private func a(_ uvi: Double, temp: Double = 25, day: Bool = true, used: Double = 0) -> Advice {
        Advisor.advice(uvi: uvi, apparent: temp, isDay: day, usedFraction: used)
    }

    func testByCategory() {
        XCTAssertEqual(a(1).level, .ok)
        XCTAssertEqual(a(4).level, .care)
        XCTAssertEqual(a(4).headline, "con protección")
        XCTAssertEqual(a(7).level, .care)
        XCTAssertEqual(a(7).headline, "con cuidado")
        XCTAssertEqual(a(9).level, .avoid)
        XCTAssertEqual(a(12).level, .stay)
    }

    func testNightIsAlwaysOk() {
        let n = a(9, temp: 40, day: false, used: 2)
        XCTAssertEqual(n.level, .ok)
        XCTAssertEqual(n.headline, "es de noche")
    }

    func testNearAndOverLimit() {
        XCTAssertEqual(a(1, used: 0.79).level, .ok)
        XCTAssertEqual(a(1, used: 0.8).level, .avoid)
        XCTAssertEqual(a(1, used: 0.8).headline, "cerca de tu límite")
        XCTAssertEqual(a(4, used: 0.9).level, .avoid)
        XCTAssertEqual(a(1, used: 1).level, .stay)
        XCTAssertEqual(a(1, used: 1).headline, "límite superado")
        XCTAssertEqual(a(12, used: 0.9).level, .stay, "no se rebaja un nivel ya mas alto")
    }

    func testHeat() {
        XCTAssertEqual(HeatLevel(apparent: 9.9), .cold)
        XCTAssertEqual(HeatLevel(apparent: 10), .comfortable)
        XCTAssertEqual(HeatLevel(apparent: 28), .warm)
        XCTAssertEqual(HeatLevel(apparent: 32), .hot)
        XCTAssertEqual(HeatLevel(apparent: 38), .danger)
        XCTAssertEqual(a(1, temp: 40).level, .avoid, "calor extremo con uv bajo: mejor evitar")
        XCTAssertTrue(a(1, temp: 40).detail.contains("hidrátate"))
        XCTAssertEqual(a(1, temp: 34).level, .ok)
        XCTAssertTrue(a(1, temp: 34).detail.contains("hidrátate"))
        XCTAssertTrue(a(1, temp: 5).detail.contains("frío"))
        XCTAssertFalse(a(1, temp: 25).detail.contains("hidrátate"))
    }

    func testColdRiskLevels() {
        XCTAssertEqual(ColdRisk(apparent: -4.9), .none)
        XCTAssertEqual(ColdRisk(apparent: -5), .none)
        XCTAssertEqual(ColdRisk(apparent: -5.1), .caution)
        XCTAssertEqual(ColdRisk(apparent: -14.9), .caution)
        XCTAssertEqual(ColdRisk(apparent: -15), .high)
        XCTAssertEqual(ColdRisk(apparent: -24.9), .high)
        XCTAssertEqual(ColdRisk(apparent: -25), .extreme)
        XCTAssertTrue(ColdRisk.none < .caution && ColdRisk.caution < .high && ColdRisk.high < .extreme)
    }

    func testAdviceWithColdRisk() {
        XCTAssertEqual(a(1, temp: -6).coldRisk, .caution)
        XCTAssertEqual(a(1, temp: -6).level, .care, "aviso de congelación sube el nivel al menos a cuidado")
        XCTAssertTrue(a(1, temp: -6).detail.contains("congelarse"))
        XCTAssertEqual(a(1, temp: -20).level, .avoid)
        XCTAssertEqual(a(12, temp: -20).level, .stay, "no se rebaja un nivel ya mas alto")
        XCTAssertEqual(a(1, temp: 10).coldRisk, .none)
    }

    func testColdRiskAtNightStillWarns() {
        let n = a(9, temp: -10, day: false, used: 0)
        XCTAssertEqual(n.level, .avoid)
        XCTAssertTrue(n.detail.contains("congelarse"))
        let mild = a(9, temp: 5, day: false, used: 0)
        XCTAssertEqual(mild.level, .ok)
    }
}

final class SunPresenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUnknownWithoutAnySample() {
        XCTAssertEqual(SunPresence.now(lastSampleEnd: nil, at: now), .unknown)
    }

    func testDirectWithinTheFreshWindow() {
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-5 * 60), at: now), .direct)
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-19 * 60 - 59), at: now), .direct)
    }

    func testShadeOnceTheSampleGoesStale() {
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-20 * 60), at: now), .shade)
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-3600), at: now), .shade)
    }

    func testCustomFreshWindow() {
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-600), at: now, freshWithin: 300), .shade)
        XCTAssertEqual(SunPresence.now(lastSampleEnd: now.addingTimeInterval(-100), at: now, freshWithin: 300), .direct)
    }
}

final class AlertTests: XCTestCase {
    private let day = hours([("06:00", 0), ("07:00", 0.5), ("08:00", 1.5), ("09:00", 3.2), ("10:00", 5), ("11:00", 6.5),
                             ("12:00", 8.5), ("13:00", 9), ("14:00", 8), ("15:00", 6), ("16:00", 4), ("17:00", 2.5), ("18:00", 1)])

    private func plan(now: String, skin: SkinType = .iii, protection: Double = 1) -> [PlannedAlert] {
        AlertPlanner.plan(hours: day, now: date(now), skin: skin, protection: protection, timeZone: utc)
    }

    func testThresholdCrossingsAndReturn() {
        let p = plan(now: "07:00")
        XCTAssertEqual(p.map(\.id), ["girasol.uv.3", "girasol.uv.6", "girasol.uv.8", "girasol.uv.down"])
        XCTAssertEqual(p[0].date, date("08:45"), "15 min antes de la hora que cruza")
        XCTAssertEqual(p[1].date, date("10:45"))
        XCTAssertEqual(p[2].date, date("11:45"))
        XCTAssertEqual(p[3].date, date("17:00"))
        XCTAssertTrue(p[0].title.contains("desde las 09:00"))
        XCTAssertTrue(p[1].title.contains("uv alto"))
        XCTAssertFalse(p.contains { $0.id == "girasol.uv.11" }, "el pico de 9 no llega a extremo")
    }

    func testNoAlertsInThePast() {
        let p = plan(now: "10:00")
        XCTAssertEqual(p.map(\.id), ["girasol.uv.6", "girasol.uv.8", "girasol.uv.down"])
        XCTAssertTrue(p.allSatisfy { $0.date > date("10:00") })
        XCTAssertEqual(plan(now: "17:30").map(\.id), [], "ya bajo: nada que avisar")
    }

    func testAlertsAreSortedAndNeverImmediate() {
        // la hora que cruza empieza dentro de 5 min: la alerta se retrasa un minuto, no sale ya
        let p = plan(now: "08:55")
        XCTAssertEqual(p.first?.id, "girasol.uv.3")
        XCTAssertEqual(p.first?.date, date("08:56"))
        XCTAssertEqual(p.map(\.date), p.map(\.date).sorted())
    }

    func testBodyReflectsSkinAndSunscreen() {
        // uv 3 cruza a las 9; pico de las 3 horas siguientes = 6.5 -> 300 / (6.5 * 1.5) = 30.8 min
        XCTAssertTrue(plan(now: "07:00")[0].body.contains("31 min"), plan(now: "07:00")[0].body)
        XCTAssertTrue(plan(now: "07:00", skin: .vi)[0].body.contains("92 min"))
        XCTAssertTrue(plan(now: "07:00", protection: 15)[0].body.contains("462 min"))
    }

    func testCloudyDayHasNoAlerts() throws {
        let s = try OpenMeteo.decode(fixture())
        let p = AlertPlanner.plan(hours: s.hours, now: s.current.time, skin: .iii, protection: 1, timeZone: s.timeZone)
        XCTAssertEqual(p, [], "el pico real de hoy fue 2.45: no alcanza ni uv moderado")
    }

    func testClockUsesTheLocationTimeZone() {
        let managua = TimeZone(secondsFromGMT: -21600)!
        XCTAssertEqual(AlertPlanner.clock(date("16:45"), managua), "10:45")
        XCTAssertEqual(AlertPlanner.clock(date("16:45"), utc), "16:45")
    }
}

final class OutlookTests: XCTestCase {
    private let day = hours([("06:00", 0), ("07:00", 0.5), ("08:00", 1.5), ("09:00", 3.2), ("10:00", 5), ("11:00", 6.5),
                             ("12:00", 8.5), ("13:00", 9), ("14:00", 8), ("15:00", 6), ("16:00", 4), ("17:00", 2.5), ("18:00", 1)])

    func testWindowsAndPeak() throws {
        let o = try XCTUnwrap(DayOutlook.make(hours: day, timeZone: utc))
        XCTAssertEqual(o.peakHour, 13)
        XCTAssertEqual(o.peakUVI, 9)
        XCTAssertEqual(o.high, .init(startHour: 11, endHour: 16))
        XCTAssertEqual(o.moderate, .init(startHour: 9, endHour: 17))
    }

    func testWindowsUseTheLocationTimeZone() throws {
        let o = try XCTUnwrap(DayOutlook.make(hours: day, timeZone: TimeZone(secondsFromGMT: -21600)!))
        XCTAssertEqual(o.peakHour, 7)
        XCTAssertEqual(o.high, .init(startHour: 5, endHour: 10))
    }

    func testCloudyDayHasNoWindows() throws {
        let s = try OpenMeteo.decode(fixture())
        let o = try XCTUnwrap(DayOutlook.make(hours: s.hours, timeZone: s.timeZone))
        XCTAssertEqual(o.peakHour, 13)
        XCTAssertEqual(o.peakUVI, 2.45)
        XCTAssertNil(o.high)
        XCTAssertNil(o.moderate)
    }

    func testEmptyHours() {
        XCTAssertNil(DayOutlook.make(hours: [], timeZone: utc))
    }

    func testUnorderedInput() throws {
        let o = try XCTUnwrap(DayOutlook.make(hours: day.reversed(), timeZone: utc))
        XCTAssertEqual(o.high, .init(startHour: 11, endHour: 16))
    }
}

final class SunscreenReminderTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testTimerRunsForTwoHours() {
        let t = SunscreenTimer(appliedAt: t0)
        XCTAssertEqual(t.due, t0.addingTimeInterval(7200))
        XCTAssertTrue(t.isActive(at: t0.addingTimeInterval(7199)))
        XCTAssertFalse(t.isActive(at: t0.addingTimeInterval(7200)))
        XCTAssertEqual(t.remaining(at: t0.addingTimeInterval(3600)), 3600)
        XCTAssertEqual(t.remaining(at: t0.addingTimeInterval(9000)), 0)
    }

    func testStartsWhenAdviceAsksForProtectionAndYouAreOutside() {
        XCTAssertTrue(SunscreenReminder.shouldStart(advice: .care, isDay: true, outdoorMinutesLastHour: 15, timer: nil, now: t0))
        XCTAssertTrue(SunscreenReminder.shouldStart(advice: .stay, isDay: true, outdoorMinutesLastHour: 40, timer: nil, now: t0))
    }

    func testDoesNotStartWithoutAllConditions() {
        XCTAssertFalse(SunscreenReminder.shouldStart(advice: .ok, isDay: true, outdoorMinutesLastHour: 40, timer: nil, now: t0), "uv bajo")
        XCTAssertFalse(SunscreenReminder.shouldStart(advice: .care, isDay: false, outdoorMinutesLastHour: 40, timer: nil, now: t0), "de noche")
        XCTAssertFalse(SunscreenReminder.shouldStart(advice: .care, isDay: true, outdoorMinutesLastHour: 14.9, timer: nil, now: t0), "poco tiempo fuera")
    }

    func testDoesNotRestartWhileOneIsRunningButDoesAfterItExpires() {
        let running = SunscreenTimer(appliedAt: t0.addingTimeInterval(-3600))
        XCTAssertFalse(SunscreenReminder.shouldStart(advice: .care, isDay: true, outdoorMinutesLastHour: 30, timer: running, now: t0))
        let expired = SunscreenTimer(appliedAt: t0.addingTimeInterval(-7200))
        XCTAssertTrue(SunscreenReminder.shouldStart(advice: .care, isDay: true, outdoorMinutesLastHour: 30, timer: expired, now: t0))
    }

    func testOutdoorMinutesOfTheLastHourSplitAcrossBuckets() {
        // son las 10:30: la ventana va de 09:30 a 10:30; 09:00 aporta media hora de su cubo, 10:00 otra media
        let now = Date(timeIntervalSince1970: 1_800_000_000 + 1800)
        let nine = now.addingTimeInterval(-5400), ten = now.addingTimeInterval(-1800)
        XCTAssertEqual(SunscreenReminder.outdoorMinutes(lastHourOf: now, buckets: [nine: 40, ten: 20]), 20 + 10, accuracy: 1e-9)
        XCTAssertEqual(SunscreenReminder.outdoorMinutes(lastHourOf: now, buckets: [:]), 0)
        XCTAssertEqual(SunscreenReminder.outdoorMinutes(lastHourOf: now, buckets: [now.addingTimeInterval(-3 * 3600): 50]), 0, "fuera de la ventana")
    }
}
