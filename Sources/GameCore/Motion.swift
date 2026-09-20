import Foundation

public struct Vec3: Equatable, Sendable {
    public var x: Double, y: Double, z: Double
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    public var length: Double { (x * x + y * y + z * z).squareRoot() }
    public static let zero = Vec3(x: 0, y: 0, z: 0)
}

/// orientacion del reloj en radianes (cmattitude).
public struct Attitude: Equatable, Codable, Sendable {
    public var roll: Double, pitch: Double, yaw: Double
    public init(roll: Double, pitch: Double, yaw: Double) { self.roll = roll; self.pitch = pitch; self.yaw = yaw }
    public func value(_ axis: Axis) -> Double {
        switch axis { case .roll: roll; case .pitch: pitch; case .yaw: yaw }
    }
}

public enum Axis: String, Codable, CaseIterable, Sendable { case roll, pitch, yaw }

/// una lectura del sensor de movimiento: aceleracion del usuario (sin gravedad, en g), giro (rad/s) y orientacion.
public struct MotionSample: Equatable, Sendable {
    public var t: Double
    public var accel: Vec3
    public var gyro: Vec3
    public var attitude: Attitude
    public init(t: Double, accel: Vec3 = .zero, gyro: Vec3 = .zero, attitude: Attitude = Attitude(roll: 0, pitch: 0, yaw: 0)) {
        self.t = t; self.accel = accel; self.gyro = gyro; self.attitude = attitude
    }
}

/// un gesto de lanzar / golpear / disparar: el pico de aceleracion y como estaba la muñeca.
public struct Swing: Equatable, Sendable {
    public var time: Double
    public var power: Double        // pico de |aceleracion| en g
    public var duration: Double     // segundos por encima del umbral
    public var direction: Vec3      // direccion de la aceleracion en el pico (unitaria)
    public var attitude: Attitude   // orientacion en el pico
    public var steadiness: Double   // 0...1: quietud de la mano justo antes del gesto
    public var gyroPeak: Double

    public init(time: Double, power: Double, duration: Double, direction: Vec3, attitude: Attitude, steadiness: Double, gyroPeak: Double) {
        self.time = time; self.power = power; self.duration = duration; self.direction = direction
        self.attitude = attitude; self.steadiness = steadiness; self.gyroPeak = gyroPeak
    }
}

/// detecta gestos bruscos por el pico de |aceleracion|. se emite en cuanto la señal empieza a bajar del pico,
/// para que el disparo se sienta inmediato.
public struct SwingDetector: Sendable {
    public var threshold: Double
    public var cooldown: Double
    public var minDuration: Double

    private var above = false
    private var startT = 0.0
    private var peak = 0.0
    private var peakSample = MotionSample(t: 0)
    private var gyroPeak = 0.0
    private var steadyAtStart = 1.0
    private var lastEmit = -Double.infinity
    private var history: [(t: Double, mag: Double)] = []

    public init(threshold: Double = 0.8, cooldown: Double = 0.7, minDuration: Double = 0.03) {
        self.threshold = threshold; self.cooldown = cooldown; self.minDuration = minDuration
    }

    public mutating func reset() { above = false; history.removeAll(); lastEmit = -.infinity }

    public mutating func feed(_ s: MotionSample) -> Swing? {
        let mag = s.accel.length
        history.append((s.t, mag))
        history.removeAll { s.t - $0.t > 1.0 }

        if !above {
            guard mag >= threshold, s.t - lastEmit >= cooldown else { return nil }
            above = true
            startT = s.t
            peak = mag
            peakSample = s
            gyroPeak = s.gyro.length
            steadyAtStart = Self.steadiness(history.filter { $0.t < s.t - 0.05 && $0.t >= s.t - 0.55 }.map(\.mag))
            return nil
        }

        if mag > peak { peak = mag; peakSample = s }
        gyroPeak = max(gyroPeak, s.gyro.length)
        guard mag < peak * 0.85 || s.t - startT > 0.35 else { return nil }

        above = false
        let duration = s.t - startT
        guard duration >= minDuration else { return nil }
        lastEmit = s.t
        let a = peakSample.accel
        let len = max(a.length, 1e-9)
        return Swing(time: peakSample.t, power: peak, duration: duration,
                     direction: Vec3(x: a.x / len, y: a.y / len, z: a.z / len),
                     attitude: peakSample.attitude, steadiness: steadyAtStart, gyroPeak: gyroPeak)
    }

    /// 1 = la mano estaba quieta; baja con el temblor previo al gesto.
    public static func steadiness(_ mags: [Double]) -> Double {
        guard mags.count >= 3 else { return 1 }
        let mean = mags.reduce(0, +) / Double(mags.count)
        let variance = mags.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(mags.count)
        return max(0, 1 - variance.squareRoot() / 0.25)
    }
}

/// convierte la orientacion del reloj en un punto de mira. los ejes del reloj cambian segun la muñeca y el lado de la
/// corona, asi que se aprenden con una calibracion: quieto, inclinar a la izquierda, inclinar hacia arriba.
public struct AimMapping: Codable, Equatable, Sendable {
    public var horizontal: Axis
    public var horizontalSign: Double
    public var horizontalRange: Double
    public var vertical: Axis
    public var verticalSign: Double
    public var verticalRange: Double
    public var neutral: Attitude

    static func wrap(_ a: Double) -> Double {
        var d = a.truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
        return d
    }

    /// nil si algun movimiento fue demasiado pequeño (< ~9 grados) o los dos usaron el mismo eje.
    public static func calibrate(neutral: Attitude, left: Attitude, up: Attitude) -> AimMapping? {
        func deltas(_ a: Attitude) -> [(Axis, Double)] { Axis.allCases.map { ($0, wrap(a.value($0) - neutral.value($0))) } }
        guard let h = deltas(left).max(by: { abs($0.1) < abs($1.1) }), abs(h.1) >= 0.15 else { return nil }
        guard let v = deltas(up).filter({ $0.0 != h.0 }).max(by: { abs($0.1) < abs($1.1) }), abs(v.1) >= 0.15 else { return nil }
        // el alcance completo es el movimiento que hizo (entre 0.25 y 0.8 rad)
        return AimMapping(horizontal: h.0, horizontalSign: h.1 > 0 ? -1 : 1, horizontalRange: min(0.8, max(0.25, abs(h.1))),
                          vertical: v.0, verticalSign: v.1 > 0 ? 1 : -1, verticalRange: min(0.8, max(0.25, abs(v.1))), neutral: neutral)
    }

    /// x hacia la derecha, y hacia arriba, cada uno en -1...1.
    public func point(for a: Attitude) -> Vec {
        let dx = Self.wrap(a.value(horizontal) - neutral.value(horizontal)) * horizontalSign / horizontalRange
        let dy = Self.wrap(a.value(vertical) - neutral.value(vertical)) * verticalSign / verticalRange
        return Vec(x: min(1, max(-1, dx)), y: min(1, max(-1, dy)))
    }
}

/// punto de mira suavizado (filtro exponencial en el tiempo, no por muestra).
public struct AimTracker: Sendable {
    public var mapping: AimMapping
    public var tau = 0.07
    public private(set) var position = Vec(x: 0, y: 0)
    private var lastT: Double?

    public init(mapping: AimMapping) { self.mapping = mapping }

    @discardableResult
    public mutating func update(_ s: MotionSample) -> Vec {
        let target = mapping.point(for: s.attitude)
        if let last = lastT {
            let alpha = 1 - exp(-max(0, s.t - last) / tau)
            position = Vec(x: position.x + (target.x - position.x) * alpha, y: position.y + (target.y - position.y) * alpha)
        } else {
            position = target
        }
        lastT = s.t
        return position
    }
}

/// la fuerza de tu tiro "normal" se aprende de tus primeros lanzamientos (mediana), para que el juego se adapte a ti.
public struct PowerCalibration: Codable, Equatable, Sendable {
    public static let needed = 3
    public private(set) var samples: [Double] = []

    public init() {}
    public init(reference: Double) { samples = [reference, reference, reference] }

    public var isReady: Bool { samples.count >= Self.needed }
    public var reference: Double? {
        guard isReady else { return nil }
        let s = samples.suffix(Self.needed).sorted()
        return s[s.count / 2]
    }

    public mutating func add(_ power: Double) { samples.append(power); if samples.count > 9 { samples.removeFirst() } }
    public mutating func reset() { samples.removeAll() }

    /// 1.0 = tu tiro normal.
    public func normalized(_ power: Double) -> Double { power / (reference ?? max(power, 0.01)) }
}
