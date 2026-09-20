import Foundation
import Observation
import HealthCore
import WatchKit

/// sesion de respiracion: mantiene la app viva con la muñeca baja (sesion de tiempo extendido) y vibra al ritmo del patron.
@MainActor
@Observable
final class BreathingRunner: NSObject, WKExtendedRuntimeSessionDelegate {
    enum State { case idle, running, finished }

    private(set) var state = State.idle
    private(set) var session: BreathingSession?
    private(set) var started: Date?
    private(set) var completed = false

    private var runtime: WKExtendedRuntimeSession?
    private var hapticTask: Task<Void, Never>?

    func begin(pattern: BreathingPattern, minutes: Int) {
        stopEverything()
        let s = BreathingSession(pattern: pattern, minutes: minutes)
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
                case .inhaleStart: Haptics.play(.directionUp)
                case .exhaleStart: Haptics.play(.directionDown)
                case .tick: Haptics.play(.click)
                case .hold: Haptics.play(.start)
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

    /// segundos respirados hasta ahora.
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
