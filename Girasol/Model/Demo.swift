import Foundation
import SunKit

/// datos fijos para capturas y pruebas: un dia despejado, a las 12:20.
enum Demo {
    static var calendar: Calendar { .current }

    static func clock() -> Date {
        calendar.date(bySettingHour: 12, minute: 20, second: 0, of: Date())!
    }

    static func snapshot() -> WeatherSnapshot {
        let start = calendar.startOfDay(for: clock())
        let uv: [Double] = [0, 0, 0, 0, 0, 0, 0.3, 1.2, 3.0, 5.3, 7.6, 9.4, 10.2, 10.6, 9.1, 6.8, 4.1, 1.9, 0.5, 0, 0, 0, 0, 0]
        let hours = uv.enumerated().map { i, v in
            WeatherSnapshot.Hour(start: start.addingTimeInterval(Double(i) * 3600), uvIndex: v,
                                 temperature: 24 + 8 * sin(max(0, Double(i) - 6) / 12 * .pi), apparentTemperature: 27 + 9 * sin(max(0, Double(i) - 6) / 12 * .pi))
        }
        let now = clock()
        let current = WeatherSnapshot.Current(time: now, temperature: 32, apparentTemperature: 36, uvIndex: 10.2, cloudCover: 10, isDay: true)
        return WeatherSnapshot(current: current, hours: hours, utcOffset: TimeZone.current.secondsFromGMT(for: now), fetchedAt: now)
    }

    static func daylight() -> DaylightService.Reading {
        let start = calendar.startOfDay(for: clock())
        func h(_ hour: Int) -> Date { start.addingTimeInterval(Double(hour) * 3600) }
        return .init(minutesByHour: [h(10): 6, h(11): 8, h(12): 4], lastSampleEnd: h(12).addingTimeInterval(16 * 60))
    }
}
