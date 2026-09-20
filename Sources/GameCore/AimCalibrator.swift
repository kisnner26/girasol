import Foundation

/// calibracion de la puntería sin tocar la pantalla: se queda quieto, inclina a la izquierda, vuelve al centro e
/// inclina hacia arriba. cada paso se captura solo cuando el reloj esta quieto en la postura pedida, asi que no importa
/// el pulso al pulsar un boton (que era lo que movia la muñeca y arruinaba la medicion).
public struct AimCalibrator: Sendable {
    public enum Step: Int, Sendable { case neutral, left, up }
    public enum State: Equatable, Sendable {
        case running(Step)
        case done
        case failed(Reason)
    }
    public enum Reason: Equatable, Sendable {
        case tooLittleMovement    // nunca llego al angulo pedido
        case notStill             // llego, pero no se quedo quieto
        case sameDirection        // "izquierda" y "arriba" fueron casi el mismo giro
    }

    public static let stillGyro = 0.5        // rad/s por debajo de los cuales el reloj esta quieto
    public static let neutralHold = 0.8      // s quieto para fijar la postura neutra
    public static let poseHold = 0.5         // s quieto en la postura inclinada
    public static let recenterAngle = 0.12   // rad: para pedir "arriba" hay que volver a esto del centro
    public static let timeout = 15.0         // s por paso

    public private(set) var state = State.running(.neutral)
    public private(set) var mapping: AimMapping?
    /// giro actual respecto al centro (rad); 0 mientras no hay centro.
    public private(set) var angle = 0.0
    /// 0...1: cuanto falta para capturar el paso actual.
    public private(set) var hold = 0.0
    /// ultimo paso capturado (para dar un aviso de vibracion en la vista).
    public private(set) var captures = 0

    private var neutral: Quat?
    private var left: Vec3?
    private var stillSince: Double?
    private var stepStart: Double?
    private var maxAngle = 0.0
    private var recentered = true

    public init() {}

    public var step: Step? { if case .running(let s) = state { s } else { nil } }

    public mutating func feed(_ s: MotionSample) {
        guard case .running(let current) = state else { return }
        if stepStart == nil { stepStart = s.t }
        let still = s.gyro.length < Self.stillGyro
        if still { if stillSince == nil { stillSince = s.t } } else { stillSince = nil }
        let held = still ? s.t - (stillSince ?? s.t) : 0

        switch current {
        case .neutral:
            hold = min(1, held / Self.neutralHold)
            if hold >= 1 { neutral = s.quat; angle = 0; advance(to: .left, at: s.t) }
        case .left, .up:
            guard let n = neutral else { return }
            let r = n.rotation(to: s.quat)
            angle = r.length
            maxAngle = max(maxAngle, angle)
            if current == .up, !recentered {
                // hasta no volver al centro, la postura de la izquierda no cuenta
                recentered = angle <= Self.recenterAngle
                hold = 0
            } else if angle >= AimMapping.minAngle {
                hold = min(1, held / Self.poseHold)
                if hold >= 1 { capture(r, at: s.t) }
            } else {
                hold = 0
            }
            if state == .running(current), s.t - (stepStart ?? s.t) > Self.timeout {
                state = .failed(maxAngle < AimMapping.minAngle ? .tooLittleMovement : .notStill)
            }
        }
    }

    private mutating func capture(_ rotation: Vec3, at t: Double) {
        if step == .left {
            left = rotation
            recentered = false
            advance(to: .up, at: t)
            return
        }
        guard let n = neutral, let l = left else { return }
        switch AimMapping.calibrate(neutral: n, left: l, up: rotation) {
        case .success(let m): mapping = m; captures += 1; state = .done
        case .failure(let f): state = .failed(f == .sameDirection ? .sameDirection : .tooLittleMovement)
        }
    }

    private mutating func advance(to next: Step, at t: Double) {
        captures += 1
        state = .running(next)
        stepStart = t
        stillSince = nil
        hold = 0
        maxAngle = 0
    }
}
