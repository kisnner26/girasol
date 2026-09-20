import Foundation

public struct PlannedAlert: Sendable, Equatable {
    public let id: String
    public let date: Date
    public let title: String
    public let body: String
}

/// notificaciones locales a partir del pronostico del dia: no necesitan que la app corra.
public enum AlertPlanner {
    private static let thresholds: [(uvi: Double, key: String, title: String)] = [
        (3, "3", "uv moderado"),
        (6, "6", "uv alto"),
        (8, "8", "uv muy alto"),
        (11, "11", "uv extremo"),
    ]
    private static let lead: TimeInterval = 15 * 60

    public static func plan(hours: [WeatherSnapshot.Hour], now: Date, skin: SkinType, protection: Double, timeZone: TimeZone) -> [PlannedAlert] {
        let hs = hours.sorted { $0.start < $1.start }
        var alerts: [PlannedAlert] = []

        for t in thresholds {
            // primera hora futura que cruza el umbral hacia arriba
            for i in hs.indices {
                let previous = i > 0 ? hs[i - 1].uvIndex : 0
                guard hs[i].uvIndex >= t.uvi, previous < t.uvi else { continue }
                let fire = max(hs[i].start.addingTimeInterval(-lead), now.addingTimeInterval(60))
                guard hs[i].start > now else { continue }
                let peak = hs[i...].prefix(3).map(\.uvIndex).max() ?? hs[i].uvIndex
                let limit = Exposure.minutesToLimit(uvi: peak, usedFraction: 0, skin: skin, protection: protection)
                let body = limit.map { "a este uv tu piel aguanta unos \(Int($0.rounded())) min. usa protector y busca sombra." }
                    ?? "usa protector y busca sombra."
                alerts.append(.init(id: "girasol.uv.\(t.key)", date: fire, title: "\(t.title) desde las \(clock(hs[i].start, timeZone))", body: body))
                break
            }
        }

        // cuando el uv vuelve a bajar de 3 despues de haber estado arriba
        if let peakIndex = hs.indices.max(by: { hs[$0].uvIndex < hs[$1].uvIndex }), hs[peakIndex].uvIndex >= 3,
           let back = hs[peakIndex...].first(where: { $0.uvIndex < 3 }), back.start > now {
            alerts.append(.init(id: "girasol.uv.down", date: max(back.start, now.addingTimeInterval(60)),
                                title: "el uv ya bajó", body: "buen momento para salir, uv bajo desde las \(clock(back.start, timeZone))."))
        }
        return alerts.sorted { $0.date < $1.date }
    }

    static func clock(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
