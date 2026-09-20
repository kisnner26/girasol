import Foundation

/// galeria de tiro de 30 s: toca los blancos para dispararles. el cargador tiene 6 balas y se recarga
/// girando la corona. los blancos rapidos valen mas; los "amigos" restan.
public struct Shooter: Sendable {
    public enum Kind: Equatable, Sendable { case normal, quick, friend }
    public enum Result: Equatable, Sendable { case hit(Kind), miss, empty }

    public struct Target: Equatable, Identifiable, Sendable {
        public let id: Int
        public let kind: Kind
        public let center: Vec
        public let radius: Double
        public let lifetime: Double
        public var age = 0.0
        public var remaining: Double { max(0, lifetime - age) }
    }

    public static let duration = 30.0
    public static let magazine = 6
    public static let reloadTurns = 0.5     // giro de corona acumulado para recargar
    public static let touchSlop = 0.03      // tolerancia del dedo

    public private(set) var targets: [Target] = []
    public private(set) var ammo = Shooter.magazine
    public private(set) var score = 0
    public private(set) var hits = 0
    public private(set) var shots = 0
    public private(set) var timeLeft = Shooter.duration
    public private(set) var reload = 0.0
    public private(set) var elapsed = 0.0

    private var rng: SplitMix64
    private var nextSpawn = 0.4
    private var nextId = 1

    public init(seed: UInt64 = 1) { rng = SplitMix64(seed: seed) }

    public var isOver: Bool { timeLeft <= 0 }
    public var needsReload: Bool { ammo == 0 }

    @discardableResult
    public mutating func shoot(at p: Vec) -> Result {
        guard !isOver else { return .miss }
        guard ammo > 0 else { return .empty }
        ammo -= 1
        shots += 1
        let candidates = targets.enumerated().filter { $0.element.center.distance(to: p) <= $0.element.radius + Self.touchSlop }
        // si hay varios, el mas cercano al toque; en empate, el mas reciente
        guard let best = candidates.min(by: { a, b in
            let da = a.element.center.distance(to: p), db = b.element.center.distance(to: p)
            return da == db ? a.element.id > b.element.id : da < db
        }) else { return .miss }
        let t = targets.remove(at: best.offset)
        hits += 1
        switch t.kind {
        case .normal: score += 1
        case .quick: score += 3
        case .friend: score = max(0, score - 2)
        }
        return .hit(t.kind)
    }

    /// `turns`: giro de la corona desde el ultimo aviso (cualquier sentido).
    public mutating func crown(turns: Double) {
        guard ammo < Self.magazine else { return }
        reload += abs(turns)
        if reload >= Self.reloadTurns {
            ammo = Self.magazine
            reload = 0
        }
    }

    public mutating func step(dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        timeLeft = max(0, timeLeft - dt)
        for i in targets.indices { targets[i].age += dt }
        targets.removeAll { $0.age >= $0.lifetime }

        nextSpawn -= dt
        if nextSpawn <= 0, targets.count < 5 {
            spawn()
            nextSpawn = max(0.5, 0.9 - elapsed * 0.012)
        }
    }

    private mutating func spawn() {
        let roll = Double.random(in: 0..<1, using: &rng)
        let kind: Kind = roll < 0.6 ? .normal : roll < 0.85 ? .quick : .friend
        let (radius, life): (Double, Double) = switch kind {
        case .normal: (0.12, 1.6)
        case .quick: (0.07, 0.9)
        case .friend: (0.11, 1.8)
        }
        let c = Vec(x: Double.random(in: 0.16...0.84, using: &rng), y: Double.random(in: 0.2...0.8, using: &rng))
        targets.append(Target(id: nextId, kind: kind, center: c, radius: radius, lifetime: life))
        nextId += 1
    }
}
