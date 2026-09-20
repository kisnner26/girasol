import Foundation

public enum Dartboard {
    /// sectores del tablero, de arriba en sentido horario.
    public static let order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

    /// x, y en radios del tablero (1 = borde exterior del doble); y hacia arriba.
    public static func score(x: Double, y: Double) -> Int {
        let r = (x * x + y * y).squareRoot()
        if r <= 0.037 { return 50 }
        if r <= 0.094 { return 25 }
        if r > 1.0 { return 0 }
        var a = atan2(x, y) + .pi / 20
        if a < 0 { a += 2 * .pi }
        let base = order[Int(a / (.pi / 10)) % 20]
        if r >= 0.953 { return base * 2 }
        if r >= 0.582 && r <= 0.629 { return base * 3 }
        return base
    }
}

/// dardos: 5 turnos de 3. la inclinacion de la muñeca al soltar apunta; la fuerza decide la altura; el temblor dispersa.
public struct Darts: Sendable {
    public struct Landing: Equatable, Sendable { public let x: Double, y: Double, score: Int }

    public static let dartsPerTurn = 3
    public static let turns = 5

    public private(set) var landings: [Landing] = []
    private var rng: SplitMix64

    public init(seed: UInt64 = 1) { rng = SplitMix64(seed: seed) }

    public var thrown: Int { landings.count }
    public var isOver: Bool { thrown >= Self.dartsPerTurn * Self.turns }
    public var turn: Int { min(Self.turns, thrown / Self.dartsPerTurn + 1) }
    public var dartsLeftInTurn: Int { isOver ? 0 : Self.dartsPerTurn - thrown % Self.dartsPerTurn }
    public var total: Int { landings.reduce(0) { $0 + $1.score } }
    public var average: Double { landings.isEmpty ? 0 : Double(total) / Double(landings.count) }

    /// `power` normalizada (1 = tiro normal), `aim` en -1...1 por eje, `steadiness` 0...1.
    @discardableResult
    public mutating func throwDart(power: Double, aim: Vec, steadiness: Double) -> Landing? {
        guard !isOver else { return nil }
        let sigma = 0.03 + (1 - min(1, max(0, steadiness))) * 0.20
        let dy = power < 1 ? (power - 1) * 1.1 : (power - 1) * 0.9
        let x = aim.x * 1.05 + gaussian() * sigma
        let y = aim.y * 1.05 + dy + gaussian() * sigma
        let l = Landing(x: x, y: y, score: Dartboard.score(x: x, y: y))
        landings.append(l)
        return l
    }

    private mutating func gaussian() -> Double {
        let u1 = max(Double.random(in: 0..<1, using: &rng), 1e-12), u2 = Double.random(in: 0..<1, using: &rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
