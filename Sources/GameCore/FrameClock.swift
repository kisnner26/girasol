import Foundation

/// avanza un juego con el reloj de pantalla: dt acotado para que una pausa no dispare la fisica.
public struct FrameClock {
    public init() {}
    private var last: Date?
    public mutating func dt(_ now: Date) -> Double {
        defer { last = now }
        return min(0.05, max(0, now.timeIntervalSince(last ?? now)))
    }
    public mutating func reset() { last = nil }
}
