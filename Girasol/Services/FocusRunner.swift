import Foundation
import Observation
import HealthCore
import UserNotifications

/// sesion de enfoque en curso. se guarda en el dispositivo para sobrevivir a que la app se cierre, y los cambios de fase
/// se avisan con notificaciones locales (un toque en la muñeca), no con una sesion en segundo plano.
@MainActor
@Observable
final class FocusRunner {
    static let shared = FocusRunner()

    private(set) var session: FocusSession?
    private let key = "girasol.focus.session"
    private let prefix = "girasol.focus."
    private let center = UNUserNotificationCenter.current()

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode(FocusSession.self, from: data) {
            session = saved
        }
    }

    func start(plan: FocusPlan) {
        session = FocusSession(plan: plan, start: Date())
        changed()
        Haptics.play(.start)
    }

    func pause() {
        session = session?.pausing(at: Date())
        changed()
        Haptics.play(.click)
    }

    func resume() {
        session = session?.resuming(at: Date())
        changed()
        Haptics.play(.click)
    }

    func skip() {
        session = session?.skipping(at: Date())
        changed()
        Haptics.play(.directionUp)
    }

    func stop() {
        session = nil
        changed()
        Haptics.play(.stop)
    }

    private func changed() {
        if let session, let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Task { await reschedule() }
    }

    /// reprograma los proximos cambios de fase; en pausa o sin sesion no deja ninguno pendiente.
    func reschedule() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard let session, !session.isPaused else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false else { return }
        let now = Date()
        for (i, t) in session.upcomingTransitions(from: now, count: 8).enumerated() {
            let content = UNMutableNotificationContent()
            switch t.phase {
            case .focus:
                content.title = loc("a enfocarse")
                content.body = loc("empieza la ronda \(t.round)")
            case .shortBreak:
                content.title = loc("descanso")
                content.body = loc("levántate, estírate y toma agua.")
            case .longBreak:
                content.title = loc("descanso largo")
                content.body = loc("llevas \(t.round) rondas. desconecta un rato.")
            }
            content.sound = nil
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, t.date.timeIntervalSince(now)), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(i)", content: content, trigger: trigger))
        }
    }
}
