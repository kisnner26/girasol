import Foundation
import HealthCore
import SunKit
import UserNotifications

/// alertas locales: las del pronostico se programan de una vez; las del limite salen al detectarlas.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAccess() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(_ alerts: [PlannedAlert]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("girasol.uv.") || $0.hasPrefix("girasol.limit.") })
        for a in alerts {
            let content = UNMutableNotificationContent()
            content.title = a.title
            content.body = a.body
            // aviso ambiente: un toque en la muñeca, sin sonido, para no tener que sacar el reloj a mirar.
            content.sound = nil
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

    /// aviso de reaplicar protector, `due` es cuando se cumplen las 2 h; sin fecha, lo quita.
    func scheduleSunscreen(due: Date?, hasSunscreen: Bool) async {
        center.removePendingNotificationRequests(withIdentifiers: ["girasol.sunscreen"])
        guard let due, due > Date(), await requestAccess() else { return }
        let content = UNMutableNotificationContent()
        content.title = loc("reaplica el protector")
        content.body = hasSunscreen ? loc("pasaron 2 horas desde la última vez. si sigues al sol, reaplícalo.")
                                    : loc("llevas tiempo al sol sin protector. ponte uno o busca sombra.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let interval = max(1, due.timeIntervalSinceNow)
        try? await center.add(UNNotificationRequest(identifier: "girasol.sunscreen", content: content,
                                                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
