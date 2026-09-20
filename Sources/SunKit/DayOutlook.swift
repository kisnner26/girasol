import Foundation

/// resumen del dia: pico de uv y las franjas horarias con uv moderado o alto.
public struct DayOutlook: Sendable, Equatable {
    /// [startHour, endHour) en hora local del lugar.
    public struct Window: Sendable, Equatable {
        public let startHour: Int
        public let endHour: Int
    }

    public let peakHour: Int
    public let peakUVI: Double
    public let high: Window?      // uv >= 6
    public let moderate: Window?  // uv >= 3

    public static func make(hours: [WeatherSnapshot.Hour], timeZone: TimeZone) -> DayOutlook? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let hs = hours.sorted { $0.start < $1.start }
        guard let peak = hs.max(by: { $0.uvIndex < $1.uvIndex }) else { return nil }

        func window(_ threshold: Double) -> Window? {
            let hit = hs.filter { $0.uvIndex >= threshold }
            guard let first = hit.first, let last = hit.last else { return nil }
            return Window(startHour: cal.component(.hour, from: first.start), endHour: cal.component(.hour, from: last.start) + 1)
        }
        return DayOutlook(peakHour: cal.component(.hour, from: peak.start), peakUVI: peak.uvIndex,
                          high: window(6), moderate: window(3))
    }
}
