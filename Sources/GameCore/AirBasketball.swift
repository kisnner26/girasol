import Foundation

/// baloncesto de muñeca: lanzas con un gesto, la fuerza decide si llega al aro y la inclinacion al lado.
/// cada tiro pide una distancia distinta; 1.0 es tu tiro normal (calibrado).
public struct AirBasketball: Sendable {
    public enum Outcome: Equatable, Sendable { case swish, basket, rimIn, rimOut, short, long, left, right }
    public enum Phase: Equatable, Sendable { case aiming, flying, result }

    public static let duration = 45.0
    public static let flightTime = 0.95
    public static let resultTime = 0.7
    public static let distances: [Double] = [1.0, 1.15, 0.85, 1.3, 0.75, 1.0, 1.2, 0.9]

    public private(set) var timeLeft = AirBasketball.duration
    public private(set) var score = 0
    public private(set) var streak = 0
    public private(set) var bestStreak = 0
    public private(set) var shots = 0
    public private(set) var made = 0
    public private(set) var phase = Phase.aiming
    public private(set) var outcome: Outcome?
    public private(set) var phaseTime = 0.0
    public private(set) var lastPoints = 0
    public private(set) var lastPower = 1.0
    public private(set) var lastAim = 0.0
    private var rng: SplitMix64

    public init(seed: UInt64 = 1) { rng = SplitMix64(seed: seed) }

    public var distance: Double { Self.distances[shots % Self.distances.count] }
    public var isOver: Bool { timeLeft <= 0 && phase == .aiming }
    public var flightProgress: Double { phase == .flying ? min(1, phaseTime / Self.flightTime) : (phase == .result ? 1 : 0) }

    public static func resolve(power: Double, aim: Double, distance: Double, luck: Double) -> Outcome {
        let pe = (power - distance) / distance
        let ae = aim
        if abs(pe) <= 0.12, abs(ae) <= 0.14 { return .swish }
        if abs(pe) <= 0.24, abs(ae) <= 0.30 { return .basket }
        if abs(pe) <= 0.36, abs(ae) <= 0.45 { return luck < 0.4 ? .rimIn : .rimOut }
        let eP = abs(pe) / 0.36, eA = abs(ae) / 0.45
        if eP >= eA { return pe < 0 ? .short : .long }
        return ae < 0 ? .left : .right
    }

    /// `power` normalizada (1 = tu tiro normal); `aim` en -1...1 (negativo = izquierda).
    @discardableResult
    public mutating func shoot(power: Double, aim: Double) -> Bool {
        guard phase == .aiming, timeLeft > 0 else { return false }
        let luck = Double.random(in: 0..<1, using: &rng)
        outcome = Self.resolve(power: power, aim: max(-1, min(1, aim)), distance: distance, luck: luck)
        lastPower = power
        lastAim = aim
        shots += 1
        phase = .flying
        phaseTime = 0
        return true
    }

    public mutating func step(dt: Double) {
        if timeLeft > 0 { timeLeft = max(0, timeLeft - dt) }
        guard phase != .aiming else { return }
        phaseTime += dt
        if phase == .flying, phaseTime >= Self.flightTime {
            phase = .result
            phaseTime = 0
            settle()
        } else if phase == .result, phaseTime >= Self.resultTime {
            phase = .aiming
            phaseTime = 0
            outcome = nil
        }
    }

    private mutating func settle() {
        switch outcome {
        case .swish, .basket, .rimIn:
            let base = outcome == .swish ? 3 : 2
            lastPoints = base + (streak >= 2 ? 1 : 0)
            score += lastPoints
            streak += 1
            made += 1
            bestStreak = max(bestStreak, streak)
        default:
            lastPoints = 0
            streak = 0
        }
    }
}
