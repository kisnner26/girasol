import Foundation

/// pompas para desestresar: suben con un vaiven suave y se revientan al tocarlas. sin tiempo ni puntos que perder.
public struct Bubbles: Sendable {
    public struct Bubble: Equatable, Identifiable, Sendable {
        public let id: Int
        public let baseX: Double
        public var y: Double
        public let radius: Double
        public let speed: Double
        public let phase: Double
        public func x(at time: Double) -> Double { baseX + 0.03 * sin(phase + time * 1.5) }
    }

    public static let maxBubbles = 9
    public private(set) var bubbles: [Bubble] = []
    public private(set) var popped = 0
    public private(set) var elapsed = 0.0

    private var rng: SplitMix64
    private var nextSpawn = 0.2
    private var nextId = 1

    public init(seed: UInt64 = 1) { rng = SplitMix64(seed: seed) }

    /// devuelve la pompa reventada, o nil si el toque cayo en el vacio.
    @discardableResult
    public mutating func pop(at p: Vec) -> Bubble? {
        let hit = bubbles.enumerated()
            .filter { Vec(x: $0.element.x(at: elapsed), y: $0.element.y).distance(to: p) <= $0.element.radius + 0.04 }
            .min { Vec(x: $0.element.x(at: elapsed), y: $0.element.y).distance(to: p) < Vec(x: $1.element.x(at: elapsed), y: $1.element.y).distance(to: p) }
        guard let hit else { return nil }
        popped += 1
        return bubbles.remove(at: hit.offset)
    }

    public mutating func step(dt: Double) {
        elapsed += dt
        for i in bubbles.indices { bubbles[i].y += bubbles[i].speed * dt }
        bubbles.removeAll { $0.y - $0.radius > 1.05 }   // se escapan por arriba: no pasa nada

        nextSpawn -= dt
        if nextSpawn <= 0, bubbles.count < Self.maxBubbles {
            bubbles.append(Bubble(id: nextId, baseX: Double.random(in: 0.12...0.88, using: &rng), y: -0.1,
                                  radius: Double.random(in: 0.07...0.14, using: &rng),
                                  speed: Double.random(in: 0.08...0.2, using: &rng), phase: Double.random(in: 0...6.28, using: &rng)))
            nextId += 1
            nextSpawn = Double.random(in: 0.35...0.8, using: &rng)
        }
    }
}
