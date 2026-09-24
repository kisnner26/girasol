import Foundation
import Observation
import SunKit

@MainActor
@Observable
final class AppModel {
    enum Status: Equatable { case idle, loading, ready, needsLocation, failed(String) }

    let settings = Settings()
    var status: Status = .idle
    var weather: WeatherSnapshot?
    var summary: ExposureSummary?
    var sunPresence = SunPresence.unknown
    var isCached = false

    private let location = LocationService()
    private let weatherService = WeatherService()
    private let daylight = DaylightService()
    private let notifications = NotificationService()
    private let demo: Bool
    private var reading = DaylightService.Reading(minutesByHour: [:], lastSampleEnd: nil)
    private(set) var lastRefresh: Date?
    /// temporizador de 2 h para reaplicar protector; se guarda para que sobreviva al cierre de la app.
    private(set) var sunscreenTimer: SunscreenTimer? = UserDefaults.standard.data(forKey: "girasol.sunscreenTimer")
        .flatMap { try? JSONDecoder().decode(SunscreenTimer.self, from: $0) }

    init(demo: Bool = ProcessInfo.processInfo.arguments.contains("-girasolDemo")) {
        self.demo = demo
    }

    var now: Date { demo ? Demo.clock() : Date() }

    // MARK: derivados

    var uvNow: Double {
        guard let w = weather else { return 0 }
        return now.timeIntervalSince(w.current.time) < 45 * 60 ? w.current.uvIndex : w.curve.uvi(at: now)
    }

    var advice: Advice? {
        guard let w = weather else { return nil }
        return Advisor.advice(uvi: uvNow, apparent: w.current.apparentTemperature, isDay: w.current.isDay, usedFraction: summary?.fraction ?? 0)
    }

    /// minutos que aguanta tu piel a este uv con lo que ya llevas hoy.
    var safeMinutes: Double? {
        Exposure.minutesToLimit(uvi: uvNow, usedFraction: summary?.fraction ?? 0, skin: settings.skin, protection: settings.sunscreen.protectionFactor)
    }

    var outlook: DayOutlook? {
        weather.flatMap { DayOutlook.make(hours: $0.hours, timeZone: $0.timeZone) }
    }

    // MARK: actualizacion

    func refreshIfStale() async {
        if let last = lastRefresh, Date().timeIntervalSince(last) < 10 * 60, weather != nil { return }
        await refresh()
    }

    func refresh() async {
        guard status != .loading else { return }
        status = .loading
        defer { lastRefresh = Date() }

        if demo {
            weather = Demo.snapshot()
            reading = Demo.daylight()
            isCached = false
            recompute()
            status = .ready
            return
        }

        await HealthStore.shared.requestAccess()
        do {
            let loc = try await location.current()
            weather = try await weatherService.fetch(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            isCached = false
        } catch LocationService.Failure.denied {
            if weather == nil { status = .needsLocation; return }
        } catch {
            if let cached = weatherService.cached() {
                weather = cached
                isCached = true
            } else if weather == nil {
                status = .failed(loc("no pude consultar el clima"))
                return
            }
        }

        reading = await daylight.today(now: now)
        recompute()
        if let w = weather { WidgetSync.weather(w) }
        status = .ready
        await scheduleAlerts()
        await autoSunscreen()
    }

    /// recalcula la exposicion cuando cambian la piel o el protector, sin volver a pedir datos.
    func recompute() {
        guard let w = weather else { return }
        summary = ExposureSummary.build(daylight: reading.minutesByHour, curve: w.curve, skin: settings.skin, protection: settings.sunscreen.protectionFactor)
        sunPresence = SunPresence.now(lastSampleEnd: reading.lastSampleEnd, at: now)
        if let f = summary?.fraction, !demo { HabitStore.shared.recordSun(fraction: f, day: Calendar.current.startOfDay(for: now), profile: ProfileStore.shared.profile) }
    }

    func settingsChanged() async {
        recompute()
        await scheduleAlerts()
        await scheduleSunscreenReminder()
    }

    // MARK: protector

    /// "me puse protector": empieza a contar 2 h desde ahora.
    func applySunscreen() async {
        setTimer(SunscreenTimer(appliedAt: now))
        Haptics.play(.success)
        await scheduleSunscreenReminder()
    }

    func clearSunscreen() async {
        setTimer(nil)
        await scheduleSunscreenReminder()
    }

    private func setTimer(_ t: SunscreenTimer?) {
        sunscreenTimer = t
        if let t, let data = try? JSONEncoder().encode(t) { UserDefaults.standard.set(data, forKey: "girasol.sunscreenTimer") }
        else { UserDefaults.standard.removeObject(forKey: "girasol.sunscreenTimer") }
    }

    private func scheduleSunscreenReminder() async {
        guard !demo else { return }
        let active = sunscreenTimer.flatMap { $0.isActive(at: now) ? $0 : nil }
        await notifications.scheduleSunscreen(due: settings.reapplyReminders ? active?.due : nil, hasSunscreen: settings.sunscreen.spf > 0)
    }

    /// si el consejo pide protector y llevas un rato fuera, arranca el temporizador sin que lo pidas.
    private func autoSunscreen() async {
        guard settings.reapplyReminders, let w = weather, let advice else { return }
        let outside = SunscreenReminder.outdoorMinutes(lastHourOf: now, buckets: reading.minutesByHour)
        guard SunscreenReminder.shouldStart(advice: advice.level, isDay: w.current.isDay, outdoorMinutesLastHour: outside, timer: sunscreenTimer, now: now) else { return }
        setTimer(SunscreenTimer(appliedAt: now))
        await scheduleSunscreenReminder()
    }

    private func scheduleAlerts() async {
        guard !demo, let w = weather else { return }
        guard settings.alertsEnabled else { notifications.cancelAll(); return }
        guard await notifications.requestAccess() else { return }
        let plan = AlertPlanner.plan(hours: w.hours, now: now, skin: settings.skin, protection: settings.sunscreen.protectionFactor, timeZone: w.timeZone)
        await notifications.schedule(plan)
        if let s = summary { await notifications.notifyLimit(s.stage, fraction: s.fraction, now: now) }
    }

}
