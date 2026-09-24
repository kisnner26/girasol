import Foundation

public struct WeatherSnapshot: Sendable, Equatable {
    public struct Current: Sendable, Equatable {
        public let time: Date
        public let temperature: Double
        public let apparentTemperature: Double
        public let uvIndex: Double
        public let cloudCover: Double
        public let isDay: Bool
        public let windSpeedKph: Double
        public init(time: Date, temperature: Double, apparentTemperature: Double, uvIndex: Double, cloudCover: Double, isDay: Bool, windSpeedKph: Double = 0) {
            self.time = time; self.temperature = temperature; self.apparentTemperature = apparentTemperature
            self.uvIndex = uvIndex; self.cloudCover = cloudCover; self.isDay = isDay; self.windSpeedKph = windSpeedKph
        }
    }

    public struct Hour: Sendable, Equatable {
        public let start: Date
        public let uvIndex: Double
        public let temperature: Double
        public let apparentTemperature: Double
        public let windSpeedKph: Double
        public init(start: Date, uvIndex: Double, temperature: Double, apparentTemperature: Double, windSpeedKph: Double = 0) {
            self.start = start; self.uvIndex = uvIndex; self.temperature = temperature; self.apparentTemperature = apparentTemperature
            self.windSpeedKph = windSpeedKph
        }
    }

    public let current: Current
    public let hours: [Hour]
    public let utcOffset: Int
    public let fetchedAt: Date

    public var curve: UVCurve { UVCurve(hours: hours) }
    public var timeZone: TimeZone { TimeZone(secondsFromGMT: utcOffset) ?? .current }

    public init(current: Current, hours: [Hour], utcOffset: Int, fetchedAt: Date) {
        self.current = current; self.hours = hours; self.utcOffset = utcOffset; self.fetchedAt = fetchedAt
    }
}

/// cliente de open-meteo (https://open-meteo.com, datos cc by 4.0, uso no comercial).
public enum OpenMeteo {
    public enum Failure: Error, Equatable { case malformed(String) }

    /// las coordenadas se redondean a 2 decimales (~1 km) antes de salir del reloj.
    public static func url(latitude: Double, longitude: Double) -> URL {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", latitude)),
            .init(name: "longitude", value: String(format: "%.2f", longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,uv_index,cloud_cover,is_day,wind_speed_10m"),
            .init(name: "hourly", value: "uv_index,temperature_2m,apparent_temperature,wind_speed_10m"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1"),
        ]
        return c.url!
    }

    private struct Response: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
            let apparent_temperature: Double
            let uv_index: Double
            let cloud_cover: Double
            let is_day: Int
            let wind_speed_10m: Double?
        }
        struct Hourly: Decodable {
            let time: [String]
            let uv_index: [Double?]
            let temperature_2m: [Double?]
            let apparent_temperature: [Double?]
            let wind_speed_10m: [Double?]?
        }
        let utc_offset_seconds: Int
        let current: Current
        let hourly: Hourly
    }

    public static func decode(_ data: Data, fetchedAt: Date = Date()) throws -> WeatherSnapshot {
        let r: Response
        do { r = try JSONDecoder().decode(Response.self, from: data) } catch { throw Failure.malformed("\(error)") }

        // los tiempos vienen en hora local del lugar, sin zona: se leen con su desfase.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: r.utc_offset_seconds)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let now = f.date(from: r.current.time) else { throw Failure.malformed("current.time \(r.current.time)") }

        var hours: [WeatherSnapshot.Hour] = []
        for (i, t) in r.hourly.time.enumerated() {
            guard let d = f.date(from: t) else { throw Failure.malformed("hourly.time \(t)") }
            let uv = r.hourly.uv_index.indices.contains(i) ? r.hourly.uv_index[i] : nil
            let temp = r.hourly.temperature_2m.indices.contains(i) ? r.hourly.temperature_2m[i] : nil
            let feel = r.hourly.apparent_temperature.indices.contains(i) ? r.hourly.apparent_temperature[i] : nil
            let wind = (r.hourly.wind_speed_10m?.indices.contains(i) ?? false) ? r.hourly.wind_speed_10m?[i] : nil
            guard let uv, let temp else { continue }   // un hueco de la api no debe inventar un dato
            hours.append(.init(start: d, uvIndex: uv, temperature: temp, apparentTemperature: feel ?? temp, windSpeedKph: wind ?? 0))
        }
        guard !hours.isEmpty else { throw Failure.malformed("sin datos por hora") }

        let current = WeatherSnapshot.Current(
            time: now, temperature: r.current.temperature_2m, apparentTemperature: r.current.apparent_temperature,
            uvIndex: r.current.uv_index, cloudCover: r.current.cloud_cover, isDay: r.current.is_day == 1,
            windSpeedKph: r.current.wind_speed_10m ?? 0)
        return WeatherSnapshot(current: current, hours: hours, utcOffset: r.utc_offset_seconds, fetchedAt: fetchedAt)
    }
}
