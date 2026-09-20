import XCTest
@testable import GameCore

final class ShooterTests: XCTestCase {
    private func firstTarget(_ g: inout Shooter, maxSeconds: Double = 5) -> Shooter.Target? {
        var t = 0.0
        while g.targets.isEmpty, t < maxSeconds { g.step(dt: 0.05); t += 0.05 }
        return g.targets.first
    }

    func testInitialState() {
        let g = Shooter(seed: 1)
        XCTAssertEqual(g.ammo, 6); XCTAssertEqual(g.score, 0); XCTAssertEqual(g.timeLeft, 30); XCTAssertTrue(g.targets.isEmpty)
        XCTAssertFalse(g.isOver); XCTAssertFalse(g.needsReload)
    }

    func testDeterministicBySeed() {
        func spawnList(_ seed: UInt64) -> [Vec] {
            var g = Shooter(seed: seed)
            for _ in 0..<100 { g.step(dt: 0.05) }
            return g.targets.map(\.center)
        }
        XCTAssertEqual(spawnList(7), spawnList(7))
        XCTAssertNotEqual(spawnList(7), spawnList(8))
    }

    func testTargetsStayInsideTheBoardAndNeverExceedFive() {
        var g = Shooter(seed: 3)
        for _ in 0..<600 {
            g.step(dt: 0.05)
            XCTAssertLessThanOrEqual(g.targets.count, 5)
            for t in g.targets {
                XCTAssertTrue((0.16...0.84).contains(t.center.x) && (0.2...0.8).contains(t.center.y))
            }
        }
    }

    func testHitAndTouchTolerance() throws {
        var g = Shooter(seed: 1)
        let t = try XCTUnwrap(firstTarget(&g))
        // dentro del radio + tolerancia acierta; fuera, no
        var far = g
        let outside = Vec(x: t.center.x + t.radius + 0.04, y: t.center.y)          // 0.03 de tolerancia del dedo
        XCTAssertEqual(far.shoot(at: outside), .miss)
        let inside = Vec(x: t.center.x + t.radius + 0.025, y: t.center.y)
        guard case .hit(let kind) = g.shoot(at: inside) else { return XCTFail("debia acertar") }
        XCTAssertEqual(kind, t.kind)
        XCTAssertFalse(g.targets.contains { $0.id == t.id }, "el blanco desaparece")
        XCTAssertEqual(g.ammo, 5); XCTAssertEqual(g.shots, 1); XCTAssertEqual(g.hits, 1)
    }

    func testScoringRulesByPlayingWholeGames() {
        // un bot que dispara al centro de cada blanco; el puntaje del juego debe coincidir con las reglas
        var sawKinds = Set<String>()
        for seed in 1...12 as ClosedRange<UInt64> {
            var g = Shooter(seed: seed)
            var tally = 0
            while !g.isOver {
                g.step(dt: 0.05)
                if g.needsReload { g.crown(turns: 1) }
                if let t = g.targets.first {
                    if case .hit(let k) = g.shoot(at: t.center) {
                        switch k {
                        case .normal: tally += 1; sawKinds.insert("n")
                        case .quick: tally += 3; sawKinds.insert("q")
                        case .friend: tally = max(0, tally - 2); sawKinds.insert("f")
                        }
                    }
                }
            }
            XCTAssertEqual(g.score, tally, "semilla \(seed)")
            XCTAssertGreaterThan(g.hits, 5)
        }
        XCTAssertEqual(sawKinds, ["n", "q", "f"], "salen los tres tipos de blanco")
    }

    func testMissAndEmptyMagazineAndReload() {
        var g = Shooter(seed: 1)
        for _ in 0..<6 { XCTAssertEqual(g.shoot(at: Vec(x: 0.0, y: 0.0)), .miss) }
        XCTAssertTrue(g.needsReload)
        XCTAssertEqual(g.shoot(at: Vec(x: 0, y: 0)), .empty)
        XCTAssertEqual(g.shots, 6, "sin balas no cuenta como disparo")
        g.crown(turns: 0.3)
        XCTAssertEqual(g.ammo, 0)
        XCTAssertEqual(g.reload, 0.3, accuracy: 1e-9)
        g.crown(turns: 0.15)
        XCTAssertEqual(g.ammo, 0, "0.45 giros aun no bastan")
        g.crown(turns: -0.1)
        XCTAssertEqual(g.ammo, 6, "0.55 giros si")
        for _ in 0..<6 { g.shoot(at: Vec(x: 0, y: 0)) }
        g.crown(turns: 0.3)
        g.crown(turns: -0.3)          // el sentido no importa
        XCTAssertEqual(g.ammo, 6)
        XCTAssertEqual(g.reload, 0)
        g.crown(turns: 5)
        XCTAssertEqual(g.reload, 0, "con el cargador lleno la corona no acumula")
    }

    func testPartialReloadWhenNotEmpty() {
        var g = Shooter(seed: 1)
        g.shoot(at: Vec(x: 0, y: 0))
        XCTAssertEqual(g.ammo, 5)
        g.crown(turns: 0.6)
        XCTAssertEqual(g.ammo, 6)
    }

    func testTargetsExpire() throws {
        var g = Shooter(seed: 1)
        let t = try XCTUnwrap(firstTarget(&g))
        let id = t.id
        for _ in 0..<Int((t.lifetime + 0.2) / 0.05) { g.step(dt: 0.05) }
        XCTAssertFalse(g.targets.contains { $0.id == id })
    }

    func testGameOver() {
        var g = Shooter(seed: 1)
        for _ in 0..<(31 * 20) { g.step(dt: 0.05) }
        XCTAssertTrue(g.isOver)
        XCTAssertEqual(g.shoot(at: Vec(x: 0.5, y: 0.5)), .miss)
        XCTAssertEqual(g.ammo, 6, "terminada: no gasta balas")
        let e = g.elapsed
        g.step(dt: 1)
        XCTAssertEqual(g.elapsed, e)
    }

    func testOverlappingTargetsPickTheNearest() throws {
        // busca una semilla en la que haya dos blancos cercanos y dispara entre ellos
        for seed in 1...400 as ClosedRange<UInt64> {
            var g = Shooter(seed: seed)
            for _ in 0..<80 { g.step(dt: 0.05) }
            let ts = g.targets
            for a in ts { for b in ts where a.id < b.id {
                let p = Vec(x: a.center.x + (b.center.x - a.center.x) * 0.25, y: a.center.y + (b.center.y - a.center.y) * 0.25)
                let da = a.center.distance(to: p), db = b.center.distance(to: p)
                guard da <= a.radius + Shooter.touchSlop, db <= b.radius + Shooter.touchSlop else { continue }
                var game = g
                if case .hit(let k) = game.shoot(at: p) {
                    XCTAssertEqual(k, a.kind, "el mas cercano (a) se lleva el tiro")
                    XCTAssertEqual(game.targets.count, ts.count - 1)
                    XCTAssertTrue(game.targets.contains { $0.id == b.id })
                    return
                }
            } }
        }
        throw XCTSkip("no hubo dos blancos solapados en 400 semillas")
    }
}

final class BubblesTests: XCTestCase {
    func testSpawnAndCap() {
        var g = Bubbles(seed: 1)
        var peak = 0
        XCTAssertTrue(g.bubbles.isEmpty)
        for _ in 0..<1200 { g.step(dt: 0.05); XCTAssertLessThanOrEqual(g.bubbles.count, 9); peak = max(peak, g.bubbles.count) }
        XCTAssertGreaterThan(g.bubbles.count, 2)
        XCTAssertEqual(peak, 9, "el tope se alcanza y se respeta")
    }

    func testBubblesRiseAndEscapeSilently() {
        var g = Bubbles(seed: 2)
        for _ in 0..<40 { g.step(dt: 0.05) }
        let b = g.bubbles.first
        XCTAssertNotNil(b)
        let y0 = b!.y
        g.step(dt: 0.5)
        XCTAssertGreaterThan(g.bubbles.first { $0.id == b!.id }?.y ?? 2, y0)
        for _ in 0..<2000 { g.step(dt: 0.05) }
        XCTAssertTrue(g.bubbles.allSatisfy { $0.y - $0.radius <= 1.05 }, "las que salen por arriba se retiran")
        XCTAssertEqual(g.popped, 0, "escaparse no cuenta ni castiga")
    }

    func testPopping() throws {
        var g = Bubbles(seed: 3)
        for _ in 0..<60 { g.step(dt: 0.05) }
        let b = try XCTUnwrap(g.bubbles.first { $0.y > 0 })
        let count = g.bubbles.count
        let popped = g.pop(at: Vec(x: b.x(at: g.elapsed), y: b.y))
        XCTAssertEqual(popped?.id, b.id)
        XCTAssertEqual(g.popped, 1)
        XCTAssertEqual(g.bubbles.count, count - 1)
        XCTAssertNil(g.pop(at: Vec(x: 5, y: 5)), "un toque en el vacio no revienta nada")
        // tolerancia del dedo: 0.04 mas alla del borde
        let c = try XCTUnwrap(g.bubbles.first)
        XCTAssertNil(g.pop(at: Vec(x: c.x(at: g.elapsed) + c.radius + 0.07, y: c.y)))
        XCTAssertNotNil(g.pop(at: Vec(x: c.x(at: g.elapsed) + c.radius + 0.03, y: c.y)))
        XCTAssertEqual(g.popped, 2)
    }

    func testDeterministicBySeed() {
        func run(_ s: UInt64) -> [Double] {
            var g = Bubbles(seed: s)
            for _ in 0..<100 { g.step(dt: 0.05) }
            return g.bubbles.map(\.baseX)
        }
        XCTAssertEqual(run(4), run(4))
        XCTAssertNotEqual(run(4), run(5))
    }
}
