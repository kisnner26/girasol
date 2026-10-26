import Foundation
import Security

/// lo que la app le deja a las complicaciones: el pronostico de uv de hoy y los totales del dia.
/// las cuentas gratuitas de apple no pueden usar app groups, asi que se comparte por el llavero: la app y la
/// extension declaran el mismo grupo de llavero y leen y escriben el mismo elemento.
struct WidgetSnapshot: Codable, Equatable {
    struct Point: Codable, Equatable { var start: Date; var uvi: Double }

    private static let service = "girasol.widget.snapshot"

    var updated = Date.distantPast
    var uv: [Point] = []
    var apparentC: Double?
    var waterMl = 0
    var waterGoal = 2000
    var kcalRemaining = 2000
    var kcalGoal = 2000
    var steps = 0
    var stepGoal = 8000
    var language: String?

    func hasForecast(at date: Date) -> Bool { uvi(at: date) != nil }
    var waterFraction: Double { min(1, Double(waterMl) / Double(max(1, waterGoal))) }
    var kcalFraction: Double { min(1, Double(max(0, kcalGoal - kcalRemaining)) / Double(max(1, kcalGoal))) }

    /// nil fuera de la cobertura horaria; cero es una lectura valida, no ausencia de datos.
    func uvi(at date: Date) -> Double? {
        let pts = uv.sorted { $0.start < $1.start }
        guard !pts.isEmpty, pts.allSatisfy({ $0.uvi.isFinite && $0.uvi >= 0 }),
              let first = pts.first, let last = pts.last else { return nil }
        if date < first.start || date >= last.start.addingTimeInterval(3600) { return nil }
        if let exact = pts.first(where: { $0.start == date }) { return exact.uvi }
        if date >= last.start { return last.uvi }
        for i in 1..<pts.count where date <= pts[i].start {
            let (a, b) = (pts[i - 1], pts[i])
            let interval = b.start.timeIntervalSince(a.start)
            guard interval > 0, interval <= 3600 else { return date == b.start ? b.uvi : nil }
            let t = date.timeIntervalSince(a.start) / interval
            return a.uvi + (b.uvi - a.uvi) * t
        }
        return last.uvi
    }

    /// hora del pico de uv de hoy.
    var peak: Point? { uv.max { $0.uvi < $1.uvi } }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "today"]
    }

    static func load() -> WidgetSnapshot {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return s
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let update = SecItemUpdate(Self.query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = Self.query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    /// lee, modifica y guarda de una vez.
    static func update(_ change: (inout WidgetSnapshot) -> Void) {
        var s = load()
        change(&s)
        s.updated = Date()
        s.save()
    }
}
