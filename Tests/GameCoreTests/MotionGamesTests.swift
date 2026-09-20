import XCTest
@testable import GameCore

// MARK: - ayudantes

/// pulso de aceleracion en forma de campana (sin²) de `peak` g y `duration` s, muestreado a `hz`.
private func pulse(peak: Double, duration: Double, at t0: Double, hz: Double = 60, dir: Vec3 = Vec3(x: 0, y: 1, z: 0),
                   roll: (Double) -> Double = { _ in 0 }) -> [MotionSample] {
    let n = Int(duration * hz)
    return (0...n).map { i in
        let u = Double(i) / Double(max(1, n))
        let m = peak * pow(sin(.pi * u), 2)
        let t = t0 + Double(i) / hz
        return MotionSample(t: t, accel: Vec3(x: dir.x * m, y: dir.y * m, z: dir.z * m), gyro: Vec3(x: m, y: 0, z: 0),
                            attitude: Attitude(roll: roll(t), pitch: 0, yaw: 0))
    }
}

/// reposo con ruido determinista de amplitud `noise` g.
private func rest(from t0: Double, to t1: Double, hz: Double = 60, noise: Double = 0, seed: UInt64 = 5) -> [MotionSample] {
    var rng = SplitMix64(seed: seed)
    return stride(from: t0, to: t1, by: 1 / hz).map { t in
        let n = noise == 0 ? Vec3.zero : Vec3(x: Double.random(in: -noise...noise, using: &rng), y: Double.random(in: -noise...noise, using: &rng), z: Double.random(in: -noise...noise, using: &rng))
        return MotionSample(t: t, accel: n)
    }
}

private func feedAll(_ d: inout SwingDetector, _ samples: [MotionSample]) -> [Swing] {
    samples.compactMap { d.feed($0) }
}

private func att(_ r: Double, _ p: Double, _ y: Double) -> Attitude { Attitude(roll: r, pitch: p, yaw: y) }

// MARK: - detector de gestos

final class SwingDetectorTests: XCTestCase {
    func testDetectsASingleThrow() throws {
        var d = SwingDetector(threshold: 0.8)
        let s = feedAll(&d, rest(from: 0, to: 1) + pulse(peak: 2.0, duration: 0.25, at: 1.0, dir: Vec3(x: 0.6, y: 0.8, z: 0)) + rest(from: 1.3, to: 2.5))
        XCTAssertEqual(s.count, 1)
        let sw = try XCTUnwrap(s.first)
        XCTAssertEqual(sw.power, 2.0, accuracy: 0.05)
        XCTAssertEqual(sw.time, 1.125, accuracy: 0.03, "el instante del pico")
        XCTAssertEqual(sw.direction.x, 0.6, accuracy: 0.05)
        XCTAssertEqual(sw.direction.y, 0.8, accuracy: 0.05)
        XCTAssertGreaterThan(sw.duration, 0.03)
        XCTAssertGreaterThanOrEqual(sw.power, 0.8)
    }

    func testIgnoresWeakMovements() {
        var d = SwingDetector(threshold: 0.8)
        XCTAssertEqual(feedAll(&d, pulse(peak: 0.5, duration: 0.3, at: 0)).count, 0)
        XCTAssertEqual(feedAll(&d, rest(from: 1, to: 6, noise: 0.15)).count, 0, "temblor de la mano")
    }

    func testIgnoresWalkingLikeMotion() {
        var d = SwingDetector(threshold: 0.8)
        let walk = (0..<600).map { i -> MotionSample in
            let t = Double(i) / 60
            return MotionSample(t: t, accel: Vec3(x: 0, y: 0.4 * sin(2 * .pi * 2 * t), z: 0))
        }
        XCTAssertEqual(feedAll(&d, walk).count, 0)
    }

    func testTwoThrowsAndCooldown() {
        var d = SwingDetector(threshold: 0.8)
        XCTAssertEqual(feedAll(&d, pulse(peak: 2, duration: 0.25, at: 0) + rest(from: 0.3, to: 1) + pulse(peak: 2, duration: 0.25, at: 1.0) + rest(from: 1.3, to: 2)).count, 2)
        var e = SwingDetector(threshold: 0.8)
        let quick = pulse(peak: 2, duration: 0.2, at: 0) + rest(from: 0.25, to: 0.3) + pulse(peak: 2, duration: 0.2, at: 0.3)
        XCTAssertEqual(feedAll(&e, quick).count, 1, "dentro del cooldown de 0.7 s no cuenta un segundo")
    }

    func testThresholdIsConfigurable() {
        let p = pulse(peak: 1.0, duration: 0.3, at: 0)
        var strict = SwingDetector(threshold: 1.2)
        var loose = SwingDetector(threshold: 0.8)
        XCTAssertEqual(feedAll(&strict, p).count, 0)
        XCTAssertEqual(feedAll(&loose, p).count, 1)
    }

    func testWorksAtDifferentSampleRates() throws {
        for hz in [30.0, 50, 60, 100] {
            var d = SwingDetector(threshold: 0.8)
            let s = feedAll(&d, rest(from: 0, to: 1, hz: hz) + pulse(peak: 2, duration: 0.25, at: 1.0, hz: hz) + rest(from: 1.3, to: 2.5, hz: hz))
            XCTAssertEqual(s.count, 1, "\(hz) Hz")
            XCTAssertEqual(try XCTUnwrap(s.first).power, 2.0, accuracy: hz < 50 ? 0.25 : 0.1, "\(hz) Hz")
        }
    }

    func testSingleSampleSpikeIsNoise() {
        var d = SwingDetector(threshold: 0.8)
        let spike = rest(from: 0, to: 0.5, hz: 100) + [MotionSample(t: 0.5, accel: Vec3(x: 0, y: 3, z: 0))] + rest(from: 0.51, to: 1, hz: 100)
        XCTAssertEqual(feedAll(&d, spike).count, 0)
    }

    func testSustainedPushEmitsOnce() {
        var d = SwingDetector(threshold: 0.8)
        let hold = (0..<60).map { MotionSample(t: Double($0) / 60, accel: Vec3(x: 0, y: 1.2, z: 0)) }
        XCTAssertEqual(feedAll(&d, hold).count, 1)
    }

    func testAttitudeAndGyroAtPeak() throws {
        var d = SwingDetector(threshold: 0.8)
        let s = feedAll(&d, pulse(peak: 2, duration: 0.3, at: 0, roll: { $0 * 2 }) + rest(from: 0.4, to: 1))
        let sw = try XCTUnwrap(s.first)
        XCTAssertEqual(sw.attitude.roll, sw.time * 2, accuracy: 0.1, "la orientacion es la del pico")
        XCTAssertEqual(sw.gyroPeak, 2.0, accuracy: 0.1)
    }

    func testSteadiness() throws {
        var calm = SwingDetector(threshold: 0.8)
        let a = try XCTUnwrap(feedAll(&calm, rest(from: 0, to: 1.5, noise: 0.01) + pulse(peak: 2, duration: 0.25, at: 1.5) + rest(from: 1.8, to: 2.5)).first)
        var shaky = SwingDetector(threshold: 0.8)
        let b = try XCTUnwrap(feedAll(&shaky, rest(from: 0, to: 1.5, noise: 0.5, seed: 9).map { var m = $0; m.accel = Vec3(x: 0, y: min(0.7, abs(m.accel.y)), z: 0); return m }
                                  + pulse(peak: 2, duration: 0.25, at: 1.5) + rest(from: 1.8, to: 2.5)).first)
        XCTAssertGreaterThan(a.steadiness, 0.9)
        XCTAssertLessThan(b.steadiness, a.steadiness - 0.3)
        var fresh = SwingDetector(threshold: 0.8)
        let first = try XCTUnwrap(feedAll(&fresh, pulse(peak: 2, duration: 0.25, at: 0)).first)
        XCTAssertEqual(first.steadiness, 1, "sin historial previo se asume quieta")
    }

    func testResetForgetsState() {
        var d = SwingDetector(threshold: 0.8)
        _ = feedAll(&d, pulse(peak: 2, duration: 0.25, at: 0))
        d.reset()
        XCTAssertEqual(feedAll(&d, pulse(peak: 2, duration: 0.25, at: 0.3)).count, 1, "tras reset no hay cooldown")
    }
}

// MARK: - calibracion de la puntería

final class AimTests: XCTestCase {
    func testCalibrationLearnsAxesAndSigns() throws {
        let m = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.4, 0.02, 0.01), up: att(0.02, -0.5, 0)))
        XCTAssertEqual(m.horizontal, .roll); XCTAssertEqual(m.horizontalSign, -1); XCTAssertEqual(m.horizontalRange, 0.4)
        XCTAssertEqual(m.vertical, .pitch); XCTAssertEqual(m.verticalSign, -1); XCTAssertEqual(m.verticalRange, 0.5)
        XCTAssertEqual(m.point(for: att(0.4, 0, 0)).x, -1, accuracy: 1e-9, "a la izquierda")
        XCTAssertEqual(m.point(for: att(-0.2, 0, 0)).x, 0.5, accuracy: 1e-9, "hacia el otro lado")
        XCTAssertEqual(m.point(for: att(0, -0.25, 0)).y, 0.5, accuracy: 1e-9, "hacia arriba")
        XCTAssertEqual(m.point(for: att(0, 0, 0)).x, 0)
    }

    func testDifferentWristOrientationsGiveDifferentMappings() throws {
        // otra muñeca / corona: izquierda = yaw negativo, arriba = roll positivo
        let m = try XCTUnwrap(AimMapping.calibrate(neutral: att(0.1, 0.1, 0.1), left: att(0.12, 0.1, -0.4), up: att(0.6, 0.1, 0.12)))
        XCTAssertEqual(m.horizontal, .yaw); XCTAssertEqual(m.horizontalSign, 1)
        XCTAssertEqual(m.vertical, .roll); XCTAssertEqual(m.verticalSign, 1)
        XCTAssertLessThan(m.point(for: att(0.1, 0.1, -0.3)).x, 0)
        XCTAssertGreaterThan(m.point(for: att(0.5, 0.1, 0.1)).y, 0)
    }

    func testCalibrationRejectsBadMovements() {
        XCTAssertNil(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.05, 0, 0), up: att(0, 0.5, 0)), "izquierda demasiado pequeña")
        XCTAssertNil(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.4, 0, 0), up: att(0.5, 0.05, 0.05)), "arriba usa el mismo eje y el resto casi no se movio")
        XCTAssertNotNil(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.4, 0, 0), up: att(0.5, 0.3, 0)), "arriba con otro eje vale")
    }

    func testRangesAreClamped() throws {
        let big = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(1.5, 0, 0), up: att(0, 1.2, 0)))
        XCTAssertEqual(big.horizontalRange, 0.8); XCTAssertEqual(big.verticalRange, 0.8)
        let small = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.16, 0, 0), up: att(0, 0.16, 0)))
        XCTAssertEqual(small.horizontalRange, 0.25); XCTAssertEqual(small.verticalRange, 0.25)
    }

    func testPointClampsAndWrapsAngles() throws {
        let m = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 3.1), left: att(0, 0, 3.1 + 0.4 - 2 * .pi), up: att(0.4, 0, 3.1)))
        // el yaw cruza la vuelta de ±pi: el delta pequeño sigue siendo pequeño
        XCTAssertEqual(m.horizontal, .yaw)
        XCTAssertEqual(m.point(for: att(0, 0, 3.1)).x, 0, accuracy: 1e-9)
        // de 3.1 a -3.09 hay 0.0932 rad por el camino corto; horizontalSign es -1 y el alcance 0.4
        XCTAssertEqual(m.point(for: att(0, 0, -3.09)).x, -(2 * .pi - 6.19) / 0.4, accuracy: 0.001)
        XCTAssertEqual(m.point(for: att(1.0, 0, 3.1)).y, 1, "se recorta a 1")
        XCTAssertEqual(m.point(for: att(-1.0, 0, 3.1)).y, -1)
    }

    func testMappingIsCodable() throws {
        let m = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.4, 0, 0), up: att(0, 0.5, 0)))
        XCTAssertEqual(try JSONDecoder().decode(AimMapping.self, from: JSONEncoder().encode(m)), m)
    }

    func testTrackerSmoothsInTime() throws {
        let m = try XCTUnwrap(AimMapping.calibrate(neutral: att(0, 0, 0), left: att(0.4, 0, 0), up: att(0, 0.5, 0)))
        var t = AimTracker(mapping: m)
        XCTAssertEqual(t.update(MotionSample(t: 0, attitude: att(0, 0, 0))).x, 0)
        // salto a x = -1: tras una constante de tiempo, ~63 %
        let p = t.update(MotionSample(t: 0.07, attitude: att(0.4, 0, 0)))
        XCTAssertEqual(p.x, -(1 - exp(-1)), accuracy: 0.01)
        var last = p.x
        for i in 1...60 { last = t.update(MotionSample(t: 0.07 + Double(i) / 60, attitude: att(0.4, 0, 0))).x }
        XCTAssertEqual(last, -1, accuracy: 0.01)
        let same = t.update(MotionSample(t: 5, attitude: att(0.4, 0, 0))).x
        XCTAssertEqual(t.update(MotionSample(t: 5, attitude: att(0, 0, 0))).x, same, "mismo instante: no se mueve")
    }
}

final class PowerCalibrationTests: XCTestCase {
    func testReferenceIsTheMedianOfTheLastThree() {
        var c = PowerCalibration()
        XCTAssertFalse(c.isReady); XCTAssertNil(c.reference)
        c.add(1.0); c.add(3.0)
        XCTAssertFalse(c.isReady)
        c.add(2.0)
        XCTAssertTrue(c.isReady)
        XCTAssertEqual(c.reference, 2.0)
        c.add(5.0)
        XCTAssertEqual(c.reference, 3.0, "ventana de los ultimos tres: 3, 2, 5")
        XCTAssertEqual(c.normalized(3.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(c.normalized(1.5), 0.5, accuracy: 1e-9)
    }

    func testNormalizedBeforeReadyAndReset() {
        var c = PowerCalibration()
        XCTAssertEqual(c.normalized(2.5), 1.0)
        c.add(1); c.add(1); c.add(1)
        c.reset()
        XCTAssertFalse(c.isReady)
        XCTAssertTrue(PowerCalibration(reference: 1.8).isReady)
        XCTAssertEqual(PowerCalibration(reference: 1.8).reference, 1.8)
    }

    func testKeepsAtMostNineSamplesAndIsCodable() throws {
        var c = PowerCalibration()
        for i in 1...20 { c.add(Double(i)) }
        XCTAssertEqual(c.samples.count, 9)
        XCTAssertEqual(try JSONDecoder().decode(PowerCalibration.self, from: JSONEncoder().encode(c)), c)
    }
}

// MARK: - baloncesto de muñeca

final class AirBasketballTests: XCTestCase {
    private typealias G = AirBasketball

    func testResolveBoundaries() {
        func r(_ p: Double, _ a: Double, _ d: Double = 1, luck: Double = 0.9) -> G.Outcome { G.resolve(power: p, aim: a, distance: d, luck: luck) }
        XCTAssertEqual(r(1, 0), .swish)
        XCTAssertEqual(r(1.119, 0.139), .swish); XCTAssertEqual(r(0.881, -0.139), .swish)
        XCTAssertEqual(r(1.121, 0), .basket); XCTAssertEqual(r(1, 0.141), .basket)
        XCTAssertEqual(r(1.239, 0.299), .basket); XCTAssertEqual(r(0.761, -0.299), .basket)
        XCTAssertEqual(r(1.241, 0, luck: 0.1), .rimIn); XCTAssertEqual(r(1.241, 0, luck: 0.9), .rimOut)
        XCTAssertEqual(r(1, 0.451), .right, "0.451 ya esta fuera de la zona de aro")
        XCTAssertEqual(r(1.359, 0.449, luck: 0.39), .rimIn); XCTAssertEqual(r(1.359, 0.449, luck: 0.4), .rimOut)
        XCTAssertEqual(r(1.361, 0), .long, "un poco mas y ya es fallo")
    }

    func testMissesPickTheDominantError() {
        func r(_ p: Double, _ a: Double, _ d: Double = 1) -> G.Outcome { G.resolve(power: p, aim: a, distance: d, luck: 0.9) }
        XCTAssertEqual(r(0.5, 0), .short)
        XCTAssertEqual(r(1.6, 0), .long)
        XCTAssertEqual(r(1, -0.8), .left)
        XCTAssertEqual(r(1, 0.8), .right)
        XCTAssertEqual(r(0.5, 0.9), .right, "el error de puntería pesa mas que el de fuerza")
        XCTAssertEqual(r(0.2, 0.5), .short, "y aqui el de fuerza")
    }

    func testDistanceChangesWhatIsPerfect() {
        XCTAssertEqual(G.resolve(power: 1.3, aim: 0, distance: 1.3, luck: 0.9), .swish)
        XCTAssertEqual(G.resolve(power: 1.0, aim: 0, distance: 1.3, luck: 0.9), .basket, "-23 % de fuerza")
        XCTAssertEqual(G.resolve(power: 0.75, aim: 0, distance: 0.75, luck: 0.9), .swish)
    }

    private func play(_ g: inout G, power: Double? = nil, aim: Double = 0) {
        g.shoot(power: power ?? g.distance, aim: aim)
        g.step(dt: G.flightTime)
        g.step(dt: G.resultTime)
    }

    func testShotFlowAndPhases() {
        var g = G(seed: 1)
        XCTAssertEqual(g.phase, .aiming)
        XCTAssertTrue(g.shoot(power: 1, aim: 0))
        XCTAssertEqual(g.phase, .flying)
        XCTAssertFalse(g.shoot(power: 1, aim: 0), "ya esta en el aire")
        XCTAssertEqual(g.score, 0, "el punto cuenta al llegar al aro")
        g.step(dt: G.flightTime - 0.01)
        XCTAssertEqual(g.phase, .flying)
        XCTAssertEqual(g.flightProgress, (G.flightTime - 0.01) / G.flightTime, accuracy: 1e-9)
        g.step(dt: 0.01)
        XCTAssertEqual(g.phase, .result)
        XCTAssertEqual(g.score, 3); XCTAssertEqual(g.lastPoints, 3); XCTAssertEqual(g.made, 1)
        g.step(dt: G.resultTime)
        XCTAssertEqual(g.phase, .aiming)
        XCTAssertNil(g.outcome)
        XCTAssertEqual(g.shots, 1)
    }

    func testDistancesCycle() {
        var g = G(seed: 1)
        var seen: [Double] = []
        for _ in 0..<9 { seen.append(g.distance); play(&g) }
        XCTAssertEqual(Array(seen.prefix(4)), [1.0, 1.15, 0.85, 1.3])
        XCTAssertEqual(seen[8], 1.0, "vuelve a empezar")
    }

    func testStreakBonusAndReset() {
        var g = G(seed: 1)
        play(&g); play(&g); play(&g)                        // tres swish seguidos: 3 + 3 + (3+1)
        XCTAssertEqual(g.score, 10)
        XCTAssertEqual(g.streak, 3); XCTAssertEqual(g.bestStreak, 3)
        play(&g, power: 0.2)                                 // corto
        XCTAssertEqual(g.streak, 0); XCTAssertEqual(g.bestStreak, 3)
        XCTAssertEqual(g.score, 10)
        XCTAssertEqual(g.lastPoints, 0)
        XCTAssertEqual(g.made, 3); XCTAssertEqual(g.shots, 4)
    }

    func testRimLuckIsDeterministicAndBothWaysHappen() {
        func outcome(_ seed: UInt64) -> G.Outcome? {
            var g = G(seed: seed)
            g.shoot(power: 1.3, aim: 0)                       // 30 % de mas: zona de aro
            return g.outcome
        }
        XCTAssertEqual(outcome(3), outcome(3))
        let all = Set((1...40).compactMap { outcome(UInt64($0)) })
        XCTAssertEqual(all, [.rimIn, .rimOut])
    }

    func testTimeRunsOut() {
        var g = G(seed: 1)
        g.step(dt: 44.9)
        XCTAssertFalse(g.isOver)
        XCTAssertTrue(g.shoot(power: 1, aim: 0))
        g.step(dt: 0.2)                                       // se acaba el tiempo con la pelota en el aire
        XCTAssertEqual(g.timeLeft, 0)
        XCTAssertFalse(g.isOver, "el tiro en el aire se completa")
        g.step(dt: G.flightTime); g.step(dt: G.resultTime)
        XCTAssertTrue(g.isOver)
        XCTAssertEqual(g.score, 3)
        XCTAssertFalse(g.shoot(power: 1, aim: 0))
    }

    func testAimIsClamped() {
        var g = G(seed: 1)
        g.shoot(power: 1, aim: 9)
        XCTAssertEqual(g.outcome, .right)
    }
}

// MARK: - dardos

final class DartsTests: XCTestCase {
    private func p(_ r: Double, degrees: Double) -> Int {
        let a = degrees * .pi / 180
        return Dartboard.score(x: r * sin(a), y: r * cos(a))
    }

    func testBullseyeAndRings() {
        XCTAssertEqual(Dartboard.score(x: 0, y: 0), 50)
        XCTAssertEqual(Dartboard.score(x: 0.037, y: 0), 50)
        XCTAssertEqual(Dartboard.score(x: 0.038, y: 0), 25)
        XCTAssertEqual(Dartboard.score(x: 0.094, y: 0), 25)
        XCTAssertEqual(p(0.095, degrees: 0), 20)
        XCTAssertEqual(p(0.3, degrees: 0), 20)
        XCTAssertEqual(p(0.6, degrees: 0), 60, "triple")
        XCTAssertEqual(p(0.582, degrees: 0), 60); XCTAssertEqual(p(0.629, degrees: 0), 60)
        XCTAssertEqual(p(0.63, degrees: 0), 20); XCTAssertEqual(p(0.58, degrees: 0), 20)
        XCTAssertEqual(p(0.97, degrees: 0), 40, "doble")
        XCTAssertEqual(p(0.953, degrees: 0), 40); XCTAssertEqual(p(0.95, degrees: 0), 20)
        XCTAssertEqual(p(1.0, degrees: 0), 40)
        XCTAssertEqual(p(1.001, degrees: 0), 0, "fuera del tablero")
    }

    func testSectorsAroundTheBoard() {
        XCTAssertEqual(p(0.3, degrees: 90), 6, "derecha")
        XCTAssertEqual(p(0.3, degrees: 180), 3, "abajo")
        XCTAssertEqual(p(0.3, degrees: 270), 11, "izquierda")
        XCTAssertEqual(p(0.3, degrees: 8), 20); XCTAssertEqual(p(0.3, degrees: 10), 1)
        XCTAssertEqual(p(0.3, degrees: -8), 20); XCTAssertEqual(p(0.3, degrees: -10), 5)
        XCTAssertEqual(Dartboard.order.count, 20)
        XCTAssertEqual(Dartboard.order.reduce(0, +), 210)
        XCTAssertEqual(Set(Dartboard.order), Set(1...20))
        for (i, s) in Dartboard.order.enumerated() { XCTAssertEqual(p(0.3, degrees: Double(i) * 18), s, "sector \(i)") }
    }

    func testGameFlow() {
        var g = Darts(seed: 1)
        XCTAssertEqual(g.turn, 1); XCTAssertEqual(g.dartsLeftInTurn, 3); XCTAssertFalse(g.isOver)
        for i in 1...15 {
            XCTAssertNotNil(g.throwDart(power: 1, aim: Vec(x: 0, y: 0), steadiness: 1))
            XCTAssertEqual(g.thrown, i)
        }
        XCTAssertTrue(g.isOver)
        XCTAssertEqual(g.turn, 5); XCTAssertEqual(g.dartsLeftInTurn, 0)
        XCTAssertNil(g.throwDart(power: 1, aim: Vec(x: 0, y: 0), steadiness: 1))
        XCTAssertEqual(g.total, g.landings.reduce(0) { $0 + $1.score })
        XCTAssertEqual(g.average, Double(g.total) / 15, accuracy: 1e-9)
    }

    func testTurnCounters() {
        var g = Darts(seed: 1)
        for _ in 0..<4 { g.throwDart(power: 1, aim: Vec(x: 0, y: 0), steadiness: 1) }
        XCTAssertEqual(g.turn, 2); XCTAssertEqual(g.dartsLeftInTurn, 2)
    }

    private func mean(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(xs.count) }
    private func std(_ xs: [Double]) -> Double { let m = mean(xs); return (xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count)).squareRoot() }

    private func landings(power: Double, aim: Vec, steadiness: Double, n: Int = 300) -> [Darts.Landing] {
        (0..<n).map { i in var g = Darts(seed: UInt64(i + 1)); return g.throwDart(power: power, aim: aim, steadiness: steadiness)! }
    }

    func testPerfectThrowHitsTheMiddle() {
        let l = landings(power: 1, aim: Vec(x: 0, y: 0), steadiness: 1)
        XCTAssertLessThan(hypot(mean(l.map(\.x)), mean(l.map(\.y))), 0.02)
        XCTAssertGreaterThan(mean(l.map { Double($0.score) }), 20, "casi todo en el centro")
    }

    func testPowerControlsHeight() {
        XCTAssertEqual(mean(landings(power: 0.5, aim: Vec(x: 0, y: 0), steadiness: 1).map(\.y)), -0.55, accuracy: 0.02)
        XCTAssertEqual(mean(landings(power: 1.5, aim: Vec(x: 0, y: 0), steadiness: 1).map(\.y)), 0.45, accuracy: 0.02)
    }

    func testTiltAims() {
        let right = landings(power: 1, aim: Vec(x: 0.5, y: 0), steadiness: 1)
        XCTAssertEqual(mean(right.map(\.x)), 0.525, accuracy: 0.02)
        let up = landings(power: 1, aim: Vec(x: 0, y: -0.5), steadiness: 1)
        XCTAssertEqual(mean(up.map(\.y)), -0.525, accuracy: 0.02)
    }

    func testShakinessSpreadsTheDarts() {
        let steady = std(landings(power: 1, aim: Vec(x: 0, y: 0), steadiness: 1).map(\.x))
        let shaky = std(landings(power: 1, aim: Vec(x: 0, y: 0), steadiness: 0).map(\.x))
        XCTAssertEqual(steady, 0.03, accuracy: 0.008)
        XCTAssertEqual(shaky, 0.23, accuracy: 0.03)
        XCTAssertGreaterThan(shaky, steady * 5)
    }

    func testDeterministicBySeed() {
        var a = Darts(seed: 42), b = Darts(seed: 42)
        XCTAssertEqual(a.throwDart(power: 1.1, aim: Vec(x: 0.2, y: 0.1), steadiness: 0.5), b.throwDart(power: 1.1, aim: Vec(x: 0.2, y: 0.1), steadiness: 0.5))
    }
}

// MARK: - tenis

final class TennisTests: XCTestCase {
    private func incoming(_ seed: UInt64 = 1) -> Tennis {
        var g = Tennis(seed: seed)
        g.step(dt: 0.9)
        return g
    }

    func testStartsWaitingAndIgnoresEarlySwings() {
        var g = Tennis(seed: 1)
        XCTAssertEqual(g.phase, .waiting)
        XCTAssertNil(g.swing(), "sin pelota en camino no pasa nada")
        XCTAssertEqual(g.livesLeft, 3)
        g.step(dt: 0.89); XCTAssertEqual(g.phase, .waiting)
        g.step(dt: 0.02); XCTAssertEqual(g.phase, .incoming)
        XCTAssertEqual(g.approach, 1.4)
        XCTAssertTrue((-1.0...1.0).contains(g.lane))
    }

    private func swing(atError err: Double) -> (Tennis.Return?, Tennis) {
        var g = incoming()
        g.step(dt: g.approach + err)
        let r = g.swing()
        return (r, g)
    }

    func testTimingWindows() {
        XCTAssertEqual(swing(atError: 0).0, .perfect)
        XCTAssertEqual(swing(atError: -0.089).0, .perfect); XCTAssertEqual(swing(atError: 0.089).0, .perfect)
        XCTAssertEqual(swing(atError: -0.091).0, .good); XCTAssertEqual(swing(atError: 0.091).0, .good)
        XCTAssertEqual(swing(atError: -0.219).0, .good); XCTAssertEqual(swing(atError: 0.219).0, .good)
        XCTAssertEqual(swing(atError: -0.221).0, .early); XCTAssertEqual(swing(atError: -0.449).0, .early)
        XCTAssertNil(swing(atError: -0.46).0, "demasiado pronto: ni cuenta")
        XCTAssertEqual(swing(atError: 0.221).0, .late); XCTAssertEqual(swing(atError: 0.299).0, .late)
    }

    func testScoringAndLives() {
        var (r, g) = swing(atError: 0)
        XCTAssertEqual(r, .perfect); XCTAssertEqual(g.score, 2); XCTAssertEqual(g.rally, 1); XCTAssertEqual(g.livesLeft, 3)
        (r, g) = swing(atError: 0.15)
        XCTAssertEqual(g.score, 1); XCTAssertEqual(g.rally, 1)
        (r, g) = swing(atError: -0.3)
        XCTAssertEqual(g.score, 0); XCTAssertEqual(g.livesLeft, 2); XCTAssertEqual(g.rally, 0)
        XCTAssertEqual(g.phase, .result)
    }

    func testMissingTheBallCostsALife() {
        var g = incoming()
        g.step(dt: g.approach + 0.29)
        XCTAssertEqual(g.phase, .incoming, "aun se puede dar")
        g.step(dt: 0.02)
        XCTAssertEqual(g.phase, .result)
        XCTAssertEqual(g.lastReturn, .miss)
        XCTAssertEqual(g.livesLeft, 2)
    }

    func testGameOverAfterThreeLives() {
        var g = Tennis(seed: 1)
        for _ in 0..<3 {
            g.step(dt: 0.9)
            g.step(dt: g.approach + 0.35)   // sin golpear
            g.step(dt: 0.7)
        }
        XCTAssertTrue(g.isOver)
        XCTAssertEqual(g.livesLeft, 0)
        XCTAssertNil(g.swing())
        g.step(dt: 5)
        XCTAssertTrue(g.isOver)
    }

    func testRallyRaisesSpeedAndTracksBest() {
        var g = Tennis(seed: 1)
        var approaches: [Double] = []
        for _ in 0..<15 {
            g.step(dt: 0.9)
            approaches.append(g.approach)
            g.step(dt: g.approach)
            XCTAssertEqual(g.swing(), .perfect)
            g.step(dt: 0.7)
        }
        XCTAssertEqual(approaches[0], 1.4)
        XCTAssertEqual(approaches[10], 0.9, accuracy: 1e-9)
        XCTAssertEqual(approaches[14], 0.75, "piso de velocidad")
        XCTAssertEqual(g.bestRally, 15); XCTAssertEqual(g.score, 30)
        g.step(dt: 0.9); g.step(dt: g.approach + 0.35)
        XCTAssertEqual(g.rally, 0); XCTAssertEqual(g.bestRally, 15)
    }

    func testBallProgress() {
        var g = incoming()
        XCTAssertEqual(g.ballProgress, 0)
        g.step(dt: 0.7)
        XCTAssertEqual(g.ballProgress, 0.5, accuracy: 1e-9)
        XCTAssertEqual(g.timeToHit, 0.7, accuracy: 1e-9)
        var last = 0.0
        var h = incoming()
        for _ in 0..<100 { h.step(dt: 0.01); if h.phase == .incoming { XCTAssertGreaterThanOrEqual(h.ballProgress, last); last = h.ballProgress } }
    }

    func testLanesAreDeterministicAndVary() {
        XCTAssertEqual(incoming(7).lane, incoming(7).lane)
        XCTAssertGreaterThan(Set((1...30).map { incoming(UInt64($0)).lane }).count, 20)
    }
}

// MARK: - valores exactos que definen la sensacion de juego

final class GameFeelTests: XCTestCase {
    private func mags(_ values: [Double], step: Double = 0.05) -> [MotionSample] {
        values.enumerated().map { MotionSample(t: 1 + Double($0.offset) * step, accel: Vec3(x: 0, y: $0.element, z: 0)) }
    }

    func testSwingEndsWhenMovementFallsBelowEightyFivePercentOfThePeak() throws {
        var d = SwingDetector(threshold: 0.8)
        // pico 2.0; 1.8 sigue por encima del 85 % (1.7), 1.6 ya no
        let s = feedAll(&d, mags([0.1, 0.9, 1.4, 2.0, 1.8, 1.6, 1.0, 0.3]))
        let sw = try XCTUnwrap(s.first)
        XCTAssertEqual(sw.duration, 0.20, accuracy: 0.01, "con 95 % terminaria en 0.15")
    }

    func testALongPushIsCutAfterAThirdOfASecond() throws {
        var d = SwingDetector(threshold: 0.8)
        let s = feedAll(&d, rest(from: 0, to: 1) + (0..<60).map { MotionSample(t: 1 + Double($0) / 60, accel: Vec3(x: 0, y: 1.5, z: 0)) })
        let sw = try XCTUnwrap(s.first)
        XCTAssertEqual(sw.duration, 0.35, accuracy: 0.02)
    }

    func testBasketZoneAimLimit() {
        func r(_ a: Double) -> AirBasketball.Outcome { AirBasketball.resolve(power: 1, aim: a, distance: 1, luck: 0.9) }
        XCTAssertEqual(r(0.299), .basket)
        XCTAssertEqual(r(0.301), .rimOut, "pasado 0.30 de puntería ya es aro")
        XCTAssertEqual(r(0.35), .rimOut)
    }

    func testBallFlightTakesAlmostASecond() {
        var g = AirBasketball(seed: 1)
        g.shoot(power: 1, aim: 0)
        g.step(dt: 0.94); XCTAssertEqual(g.phase, .flying)
        g.step(dt: 0.02); XCTAssertEqual(g.phase, .result)
    }

    func testBoardLayoutIsTheRealOne() {
        XCTAssertEqual(Dartboard.order, [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5])
    }

    func testTennisPausesBeforeTheNextServe() {
        var g = Tennis(seed: 1)
        g.step(dt: 0.9)
        g.step(dt: g.approach)
        XCTAssertEqual(g.swing(), .perfect)
        g.step(dt: 0.6); XCTAssertEqual(g.phase, .result)
        g.step(dt: 0.11); XCTAssertEqual(g.phase, .waiting)
    }
}
