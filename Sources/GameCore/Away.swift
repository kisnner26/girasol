import Foundation

/// resumen de lo que paso mientras la pantalla estaba apagada o girada.
public struct AwaySummary: Equatable, Sendable {
    public struct Item: Equatable, Sendable { public let label: String; public let count: Int }
    public let items: [Item]
    public let points: Int
}

/// detecta que la pantalla dejo de dibujar (el reloj la apaga al girar la muñeca) y junta los eventos de ese rato.
/// `drew` se llama en cada fotograma dibujado; `tick` con un reloj propio que sigue corriendo aunque no se dibuje.
public struct AwayTracker: Sendable {
    public var gap = 0.6

    private var lastDraw: Double?
    private var awaySince: Double?
    private var events: [(t: Double, label: String, points: Int)] = []

    public init(gap: Double = 0.6) { self.gap = gap }

    public var isAway: Bool { awaySince != nil }

    public mutating func drew(at t: Double) { lastDraw = t }

    public mutating func note(_ label: String, points: Int = 0, at t: Double) {
        events.append((t, label, points))
    }

    /// devuelve el resumen justo cuando la pantalla vuelve, si paso algo mientras estaba apagada.
    public mutating func tick(at t: Double) -> AwaySummary? {
        guard let last = lastDraw else { return nil }
        if t - last > gap {
            if awaySince == nil { awaySince = last }
            return nil
        }
        guard let since = awaySince else {
            events.removeAll { t - $0.t > 120 }
            return nil
        }
        awaySince = nil
        let mine = events.filter { $0.t > since }
        events.removeAll { $0.t <= t }
        guard !mine.isEmpty else { return nil }
        var order: [String] = []
        var counts: [String: Int] = [:]
        for e in mine {
            if counts[e.label] == nil { order.append(e.label) }
            counts[e.label, default: 0] += 1
        }
        return AwaySummary(items: order.map { .init(label: $0, count: counts[$0]!) }, points: mine.reduce(0) { $0 + $1.points })
    }
}
