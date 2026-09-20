import Foundation

public struct Vec3: Equatable, Codable, Sendable {
    public var x: Double, y: Double, z: Double
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
    public var length: Double { (x * x + y * y + z * z).squareRoot() }
    public static let zero = Vec3(x: 0, y: 0, z: 0)

    public func dot(_ o: Vec3) -> Double { x * o.x + y * o.y + z * o.z }
    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    public static func * (a: Vec3, k: Double) -> Vec3 { Vec3(x: a.x * k, y: a.y * k, z: a.z * k) }
    /// unitario; el vector nulo se queda como esta.
    public var normalized: Vec3 { let l = length; return l > 1e-12 ? self * (1 / l) : self }
}

/// orientacion como cuaternion unitario (cmattitude.quaternion). a diferencia de los angulos de euler no depende de que
/// eje sea cual ni tiene saltos en ±pi, asi que sirve igual con cualquier muñeca o lado de la corona.
public struct Quat: Equatable, Codable, Sendable {
    public var w: Double, x: Double, y: Double, z: Double
    public init(w: Double, x: Double, y: Double, z: Double) { self.w = w; self.x = x; self.y = y; self.z = z }
    public static let identity = Quat(w: 1, x: 0, y: 0, z: 0)

    /// giro de `angle` radianes alrededor de `axis`.
    public init(axis: Vec3, angle: Double) {
        let a = axis.normalized, h = angle / 2
        self.init(w: cos(h), x: a.x * sin(h), y: a.y * sin(h), z: a.z * sin(h))
    }

    public var conjugate: Quat { Quat(w: w, x: -x, y: -y, z: -z) }

    public static func * (a: Quat, b: Quat) -> Quat {
        Quat(w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
             x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
             y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
             z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w)
    }

    /// el giro como vector: direccion = eje, longitud = angulo (rad, por el camino corto).
    public var rotationVector: Vec3 {
        let q = w < 0 ? Quat(w: -w, x: -x, y: -y, z: -z) : self
        let s = (q.x * q.x + q.y * q.y + q.z * q.z).squareRoot()
        guard s > 1e-12 else { return .zero }
        return Vec3(x: q.x, y: q.y, z: q.z) * (2 * atan2(s, q.w) / s)
    }

    /// como se ve el giro de `self` a `other`, medido en los ejes de `self`.
    public func rotation(to other: Quat) -> Vec3 { (conjugate * other).rotationVector }
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
    public var quat: Quat
    public init(t: Double, accel: Vec3 = .zero, gyro: Vec3 = .zero, attitude: Attitude = Attitude(roll: 0, pitch: 0, yaw: 0), quat: Quat = .identity) {
        self.t = t; self.accel = accel; self.gyro = gyro; self.attitude = attitude; self.quat = quat
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

/// convierte la orientacion del reloj en un punto de mira. no asume que eje del reloj es "izquierda" o "arriba" (cambian
/// con la muñeca y el lado de la corona): los aprende de una calibracion, como direcciones de giro respecto a la
/// postura neutra.
public struct AimMapping: Codable, Equatable, Sendable {
    public var neutral: Quat
    public var right: Vec3          // direccion de giro que mueve la mira a la derecha (unitaria)
    public var up: Vec3             // direccion de giro que la mueve hacia arriba (unitaria, perpendicular a `right`)
    public var horizontalRange: Double   // radianes de giro para llegar al borde
    public var verticalRange: Double

    public static let minAngle = 0.17          // ~10 grados
    public static let rangeLimits = 0.22...0.7
    public static let minSeparation = 0.45     // seno del angulo minimo entre "izquierda" y "arriba" (~27 grados)

    public init(neutral: Quat, right: Vec3, up: Vec3, horizontalRange: Double, verticalRange: Double) {
        self.neutral = neutral; self.right = right; self.up = up
        self.horizontalRange = horizontalRange; self.verticalRange = verticalRange
    }

    public enum Failure: Error, Equatable, Sendable { case tooLittleMovement, sameDirection }

    /// `left` y `up` son los giros medidos desde la postura neutra (`Quat.rotation(to:)`).
    public static func calibrate(neutral: Quat, left: Vec3, up: Vec3) -> Result<AimMapping, Failure> {
        guard left.length >= minAngle, up.length >= minAngle else { return .failure(.tooLittleMovement) }
        let right = (left * -1).normalized
        let vRaw = up - right * up.dot(right)      // lo que "arriba" tiene de distinto a "derecha"
        guard vRaw.length / up.length >= minSeparation else { return .failure(.sameDirection) }
        func clamp(_ v: Double) -> Double { min(rangeLimits.upperBound, max(rangeLimits.lowerBound, v)) }
        return .success(AimMapping(neutral: neutral, right: right, up: vRaw.normalized,
                                   horizontalRange: clamp(left.length), verticalRange: clamp(vRaw.length)))
    }

    /// x hacia la derecha, y hacia arriba, cada uno en -1...1.
    public func point(for q: Quat) -> Vec {
        let r = neutral.rotation(to: q)
        return Vec(x: min(1, max(-1, r.dot(right) / horizontalRange)), y: min(1, max(-1, r.dot(up) / verticalRange)))
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
        let target = mapping.point(for: s.quat)
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
