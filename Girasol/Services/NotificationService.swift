import Foundation
import HealthCore
import SunKit
import UserNotifications

/// alertas locales: las del pronostico se programan de una vez; las del limite salen al detectarlas.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let stageKey = "girasol.limitStage"

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ alerts: [PlannedAlert]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("girasol.uv.") })
        for a in alerts {
            let content = UNMutableNotificationContent()
            content.title = a.title
            content.body = a.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: a.date)
            let request = UNNotificationRequest(identifier: a.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    /// recordatorios de agua de hoy; sin ninguno, quita los pendientes.
    func scheduleWater(_ items: [Hydration.Reminder]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("girasol.water.") })
        guard !items.isEmpty, await requestAccess() else { return }
        for r in items {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: r.date)
            try? await center.add(UNNotificationRequest(identifier: r.id, content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// avisa una sola vez por etapa y por dia (cerca del limite, limite alcanzado).
    func notifyLimit(_ stage: LimitStage, fraction: Double, now: Date) async {
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let stored = UserDefaults.standard.dictionary(forKey: stageKey) ?? [:]
        let last = (stored["day"] as? Double) == day ? LimitStage(rawValue: stored["stage"] as? Int ?? 0) ?? .none : .none
        guard stage > last else { return }
        UserDefaults.standard.set(["day": day, "stage": stage.rawValue], forKey: stageKey)

        let content = UNMutableNotificationContent()
        content.sound = .default
        switch stage {
        case .approaching:
            content.title = "cerca de tu límite de uv"
            content.body = "llevas \(Int((fraction * 100).rounded())) % de lo que tu piel tolera hoy. busca sombra."
        case .reached:
            content.title = "límite de uv alcanzado"
            content.body = "tu piel ya recibió hoy lo que tolera. sombra y protector."
        case .none:
            return
        }
        try? await center.add(UNNotificationRequest(identifier: "girasol.limit.\(stage.rawValue)", content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
