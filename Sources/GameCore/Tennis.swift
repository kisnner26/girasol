import Foundation

/// tenis de reflejos: la pelota se acerca y hay que darle con un golpe de muñeca justo cuando llega.
public struct Tennis: Sendable {
    public enum Return: Equatable, Sendable { case perfect, good, early, late, miss }
    public enum Phase: Equatable, Sendable { case waiting, incoming, result, over }

    public static let lives = 3
    public static let perfectWindow = 0.09
    public static let goodWindow = 0.22
    public static let earlyLimit = 0.45      // se puede golpear hasta 0.45 s antes de que llegue
    public static let lateLimit = 0.30       // y hasta 0.30 s despues

    public private(set) var livesLeft = Tennis.lives
    public private(set) var score = 0
    public private(set) var rally = 0
    public private(set) var bestRally = 0
    public private(set) var phase = Phase.waiting
    public private(set) var lastReturn: Return?
    public private(set) var clock = 0.0          // segundos dentro de la fase
    public private(set) var approach = 1.4       // duracion de la aproximacion actual
    private var rng: SplitMix64
    public private(set) var lane = 0.0           // -1...1: por donde llega la pelota

    public init(seed: UInt64 = 1) { rng = SplitMix64(seed: seed) }

    public var isOver: Bool { phase == .over }
    /// 0...1: cuanto ha avanzado la pelota hacia ti.
    public var ballProgress: Double { phase == .incoming ? min(1.15, clock / approach) : (phase == .result ? 1 : 0) }
    public var timeToHit: Double { approach - clock }

    /// un golpe detectado; devuelve nil si la pelota no esta en camino (no cuesta vida).
    @discardableResult
    public mutating func swing() -> Return? {
        guard phase == .incoming else { return nil }
        let err = clock - approach
        let result: Return
        if abs(err) <= Self.perfectWindow { result = .perfect }
        else if abs(err) <= Self.goodWindow { result = .good }
        else if err < -Self.goodWindow, err >= -Self.earlyLimit { result = .early }
        else if err > Self.goodWindow, err <= Self.lateLimit { result = .late }
        else { return nil }
        resolve(result)
        return result
    }

    public mutating func step(dt: Double) {
        guard phase != .over else { return }
        clock += dt
        switch phase {
        case .waiting:
            if clock >= 0.9 {
                phase = .incoming
                clock = 0
                approach = max(0.75, 1.4 - Double(rally) * 0.05)
                lane = Double.random(in: -1...1, using: &rng)
            }
        case .incoming:
            if clock - approach > Self.lateLimit { resolve(.miss) }
        case .result:
            if clock >= 0.7 {
                if livesLeft <= 0 { phase = .over } else { phase = .waiting }
                clock = 0
            }
        case .over:
            break
        }
    }

    private mutating func resolve(_ r: Return) {
        lastReturn = r
        switch r {
        case .perfect: score += 2; rally += 1
        case .good: score += 1; rally += 1
        case .early, .late, .miss: livesLeft -= 1; rally = 0
        }
        bestRally = max(bestRally, rally)
        phase = .result
        clock = 0
    }
}
