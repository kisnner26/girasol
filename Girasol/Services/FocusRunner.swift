import Foundation
import Observation
import HealthCore
import WatchKit

/// sesion de concentracion: mantiene la app viva con la muñeca baja (sesion de tiempo extendido) y vibra al cambiar de fase.
@MainActor
@Observable
final class FocusRunner: NSObject, WKExtendedRuntimeSessionDelegate {
    enum State { case idle, running, finished }

    private(set) var state = State.idle
    private(set) var session: FocusSession?
    private(set) var started: Date?
    private(set) var completed = false

    private var runtime: WKExtendedRuntimeSession?
    private var hapticTask: Task<Void, Never>?

    func begin(pattern: FocusPattern, minutes: Int) {
        stopEverything()
        let s = FocusSession(pattern: pattern, minutes: minutes)
        session = s
        started = Date()
        completed = false
        state = .running

        let rt = WKExtendedRuntimeSession()
        rt.delegate = self
        rt.start()
        runtime = rt

        let events = s.haptics()
        let start = started!
        hapticTask = Task { [weak self] in
            for e in events {
                let wait = e.time - Date().timeIntervalSince(start)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if Task.isCancelled { return }
                switch e.kind {
                case .workStart: Haptics.play(.start)
                case .restStart: Haptics.play(.directionDown)
                case .end: Haptics.play(.success)
                }
            }
            await MainActor.run { self?.finish(completed: true) }
        }
    }

    /// termina antes de tiempo o al acabar; `completed` dice si se hicieron todos los ciclos.
    func finish(completed: Bool) {
        guard state == .running else { return }
        self.completed = completed
        state = .finished
        stopEverything(keepState: true)
    }

    func reset() {
        stopEverything()
        state = .idle
        session = nil
        started = nil
    }

    /// segundos concentrado hasta ahora.
    var elapsed: Double { started.map { min(Date().timeIntervalSince($0), session?.duration ?? 0) } ?? 0 }

    private func stopEverything(keepState: Bool = false) {
        hapticTask?.cancel()
        hapticTask = nil
        if runtime?.state == .running { runtime?.invalidate() }
        runtime = nil
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}
    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}
    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {}
}
