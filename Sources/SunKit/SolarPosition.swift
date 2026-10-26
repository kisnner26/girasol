import Foundation

/// posicion del sol en el cielo: para la brujula de sombra, no para calculos de uv (esos ya vienen del pronostico).
public enum SolarPosition {
    /// `azimuth`: 0 = norte, 90 = este, 180 = sur, 270 = oeste. `elevation`: grados sobre el horizonte (negativo si el sol ya se puso).
    /// formula de baja precision (Michalsky/NOAA), suficiente para señalar una direccion, no para navegacion.
    public static func compute(latitude: Double, longitude: Double, date: Date) -> (elevation: Double, azimuth: Double) {
        let rad = Double.pi / 180
        let deg = 180 / Double.pi

        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let d = jd - 2451545.0

        let L = fmod(280.460 + 0.9856474 * d, 360)
        let g = (fmod(357.528 + 0.9856003 * d, 360)) * rad
        let lambda = fmod(L + 1.915 * sin(g) + 0.020 * sin(2 * g), 360) * rad
        let epsilon = (23.439 - 0.0000004 * d) * rad

        let alpha = atan2(cos(epsilon) * sin(lambda), cos(lambda)) * deg
        let delta = asin(sin(epsilon) * sin(lambda)) * deg

        var eqTime = L - alpha
        if eqTime > 180 { eqTime -= 360 }
        if eqTime < -180 { eqTime += 360 }
        eqTime *= 4 // minutos

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let c = utc.dateComponents([.hour, .minute, .second], from: date)
        let utcHour = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600

        let solarTime = utcHour + longitude / 15.0 + eqTime / 60.0
        let hourAngle = (solarTime - 12) * 15 * rad

        let latRad = latitude * rad
        let deltaRad = delta * rad

        let elevation = asin(sin(latRad) * sin(deltaRad) + cos(latRad) * cos(deltaRad) * cos(hourAngle)) * deg
        let az = atan2(sin(hourAngle), cos(hourAngle) * sin(latRad) - tan(deltaRad) * cos(latRad))
        let azimuth = fmod(az * deg + 180 + 360, 360)

        return (elevation, azimuth)
    }

    /// direccion hacia la que hay que girar la espalda para dar la espalda al sol (para hacer sombra propia).
    public static func shadeHeading(latitude: Double, longitude: Double, date: Date) -> Double {
        let sun = compute(latitude: latitude, longitude: longitude, date: date).azimuth
        return fmod(sun + 180, 360)
    }
}
