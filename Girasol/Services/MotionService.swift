import CoreMotion
import Foundation
import GameCore
import Observation

/// sensores de movimiento del reloj (acelerometro + giroscopio fusionados por CoreMotion).
@MainActor
final class MotionService {
    static let shared = MotionService()

    private let manager = CMMotionManager()
    private var handler: ((MotionSample) -> Void)?
    /// ultima lectura; no es observable a proposito: se lee desde el bucle de dibujo, no dispara refrescos a 60 Hz.
    private(set) var latest = MotionSample(t: 0)
    private(set) var isRunning = false

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(hz: Double = 60, _ handler: @escaping (MotionSample) -> Void) {
        stop()
        guard manager.isDeviceMotionAvailable else { return }
        self.handler = handler
        manager.deviceMotionUpdateInterval = 1 / hz
        manager.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let m else { return }
            let s = MotionSample(
                t: m.timestamp,
                accel: Vec3(x: m.userAcceleration.x, y: m.userAcceleration.y, z: m.userAcceleration.z),
                gyro: Vec3(x: m.rotationRate.x, y: m.rotationRate.y, z: m.rotationRate.z),
                attitude: Attitude(roll: m.attitude.roll, pitch: m.attitude.pitch, yaw: m.attitude.yaw))
            MainActor.assumeIsolated {
                self?.latest = s
                self?.handler?(s)
            }
        }
        isRunning = true
    }

    func stop() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        handler = nil
        isRunning = false
    }
}

/// calibraciones y preferencias de los juegos de movimiento, guardadas en el reloj.
@MainActor
@Observable
final class MotionSettings {
    static let shared = MotionSettings()
    private let d = UserDefaults.standard

    var mapping: AimMapping? { didSet { save(mapping, "girasol.aim") } }
    var basketPower: PowerCalibration { didSet { save(basketPower, "girasol.power.basket") } }
    var dartsPower: PowerCalibration { didSet { save(dartsPower, "girasol.power.darts") } }
    var sensitivity: Double { didSet { d.set(sensitivity, forKey: "girasol.motion.sens") } }
    var showMeter: Bool { didSet { d.set(showMeter, forKey: "girasol.motion.meter") } }
    var touchMode: Bool { didSet { d.set(touchMode, forKey: "girasol.motion.touch") } }

    private init() {
        func load<T: Decodable>(_ key: String) -> T? {
            UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
        mapping = load("girasol.aim")
        basketPower = load("girasol.power.basket") ?? PowerCalibration()
        dartsPower = load("girasol.power.darts") ?? PowerCalibration()
        let s = UserDefaults.standard.double(forKey: "girasol.motion.sens")
        sensitivity = s == 0 ? 1 : min(1.6, max(0.6, s))
        showMeter = UserDefaults.standard.object(forKey: "girasol.motion.meter") as? Bool ?? true
        touchMode = UserDefaults.standard.bool(forKey: "girasol.motion.touch")
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) } else { d.removeObject(forKey: key) }
    }

    /// umbral del detector en g: mas sensibilidad = umbral mas bajo.
    var threshold: Double { 0.8 / sensitivity }
    /// sin sensores, o por eleccion, los juegos se controlan tocando la pantalla.
    var usesTouch: Bool { touchMode || !MotionService.shared.isAvailable }
}
