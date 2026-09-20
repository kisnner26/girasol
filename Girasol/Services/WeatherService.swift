import Foundation
import SunKit

/// consulta open-meteo y guarda la ultima respuesta para mostrarla sin conexion.
struct WeatherService {
    private static let cacheKey = "girasol.lastWeather"

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        var request = URLRequest(url: OpenMeteo.url(latitude: latitude, longitude: longitude))
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let snapshot = try OpenMeteo.decode(data)
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
        UserDefaults.standard.set(Date(), forKey: Self.cacheKey + ".date")
        return snapshot
    }

    /// ultima respuesta guardada, solo si es de hoy.
    func cached() -> WeatherSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let date = UserDefaults.standard.object(forKey: Self.cacheKey + ".date") as? Date,
              Calendar.current.isDateInToday(date),
              let snapshot = try? OpenMeteo.decode(data, fetchedAt: date) else { return nil }
        return snapshot
    }
}
