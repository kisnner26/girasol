import HealthKit
import SwiftUI
import WatchKit

/// mantiene la app al frente y corriendo mientras juegas: una sesion de entrenamiento (la app sigue viva con los
/// sensores activos aunque bajes la muñeca).
/// no se crea ningun constructor, asi que no se guarda ningun entrenamiento en Salud.
@MainActor
final class KeepAwake: NSObject, HKWorkoutSessionDelegate {
    static let shared = KeepAwake()

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var fallback: WKExtendedRuntimeSession?
    private var holders = 0
    private var stopTask: Task<Void, Never>?

    /// una pantalla de juego llega. contador para que pasar de la lista a un juego no reinicie la sesion.
    func acquire() {
        holders += 1
        stopTask?.cancel(); stopTask = nil
        guard session == nil, fallback == nil else { return }
        start()
    }

    func release() {
        holders = max(0, holders - 1)
        guard holders == 0 else { return }
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private func start() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown
        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: config)
            s.delegate = self
            s.startActivity(with: Date())
            session = s
        } catch {
            // sin permiso de entrenamientos: al menos la sesion extendida mantiene los sensores
            let rt = WKExtendedRuntimeSession()
            rt.start()
            fallback = rt
        }
    }

    private func stop() {
        session?.end(); session = nil
        if fallback?.state == .running { fallback?.invalidate() }
        fallback = nil
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            if self.session === workoutSession { self.session = nil }
        }
    }
}

extension View {
    /// mientras esta vista (o cualquier otra con este modificador) esta abierta, la app sigue al frente y corriendo.
    func keepAwake() -> some View {
        onAppear { KeepAwake.shared.acquire() }
            .onDisappear { KeepAwake.shared.release() }
    }
}
