import SwiftUI
import HealthCore
import SunKit

enum Route: Hashable {
    case sun, water, food, body, breathe, games, settings
    case week, sleep, airBasketball, darts, pistol, tennis, bubbles, calibrate
}

struct HomeView: View {
    @Environment(AppModel.self) private var sun
    @Environment(HealthModel.self) private var health

    var body: some View {
        let p = health.profile
        ScrollView {
            VStack(spacing: 6) {
                Text(Greeting.text(hour: Calendar.current.component(.hour, from: Date()), name: p.displayName))
                    .font(.serif(16, italic: true)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                Caption(verbatim: dayText)

                ZStack {
                    Ring(fraction: health.waterFraction, tint: Palette.moss, width: 5).frame(width: 104, height: 104)
                    Ring(fraction: health.kcalFraction, tint: Palette.olive, width: 5).frame(width: 82, height: 82)
                    Ring(fraction: sun.summary?.fraction ?? 0, tint: Palette.rose, width: 5).frame(width: 60, height: 60)
                    Text("✦").font(.serif(14)).foregroundStyle(Palette.mid)
                }
                .padding(.vertical, 6)
                HStack(spacing: 10) {
                    legend("agua", Palette.moss)
                    legend("comida", Palette.olive)
                    legend("sol", Palette.rose)
                }

                Hairline().padding(.vertical, 4)

                NavigationLink(value: Route.sun) {
                    HomeRow(icon: .sun, title: "sol", detail: sunDetail)
                }
                NavigationLink(value: Route.water) {
                    HomeRow(icon: .drop, title: "agua", detail: "\(p.volumeUnit.text(ml: health.totals.waterMl)) de \(p.volumeUnit.text(ml: p.waterGoalMl))")
                }
                NavigationLink(value: Route.food) {
                    HomeRow(icon: .leaf, title: "comida", detail: "\(numberText(health.totals.foodKcal)) de \(p.kcalGoal) kcal")
                }
                NavigationLink(value: Route.body) {
                    HomeRow(icon: .heart, title: "cuerpo", detail: bodyDetail)
                }
                NavigationLink(value: Route.week) {
                    HomeRow(icon: .leaf, title: "racha", detail: health.streak == 0 ? "empieza hoy" : (health.streak == 1 ? "1 día seguido" : "\(health.streak) días seguidos"))
                }
                NavigationLink(value: Route.sleep) {
                    HomeRow(icon: .breath, title: "sueño", detail: health.lastNight.map { LocalizedStringKey("\(String(format: "%.1f", $0.hours)) h anoche") } ?? "sin datos aún")
                }
                NavigationLink(value: Route.breathe) {
                    HomeRow(icon: .breath, title: "respirar", detail: breatheDetail)
                }
                NavigationLink(value: Route.games) {
                    HomeRow(icon: .target, title: "juegos", detail: "baloncesto · dardos · pistola · tenis")
                }
                NavigationLink(value: Route.settings) {
                    HomeRow(icon: .sliders, title: "ajustes", detail: "metas, tema, recordatorios")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .paperBackground()
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(.serif(9, italic: true)).foregroundStyle(Palette.mid)
        }
    }

    private var dayText: String {
        var s = Date.FormatStyle().weekday(.wide).day().month(.abbreviated)
        s.locale = Lang.locale
        return Date().formatted(s)
    }

    private var sunDetail: LocalizedStringKey {
        guard sun.weather != nil, let advice = sun.advice else { return "consultando…" }
        return "uv \(sun.uvNow.uvText) · \(advice.headline)"
    }

    private var bodyDetail: LocalizedStringKey {
        var parts: [String] = []
        if let hr = health.heart.latest { parts.append("♥ \(Int(hr.rounded()))") }
        if let o = health.latestOxygen { parts.append("O₂ \(Int(o.percent.rounded())) %") }
        parts.append(loc("\(numberText(health.totals.steps)) pasos"))
        return LocalizedStringKey(parts.joined(separator: " · "))
    }

    private var breatheDetail: LocalizedStringKey {
        let m = Int(health.totals.mindfulMinutes.rounded())
        return m > 0 ? "\(m) min hoy" : "1 minuto de calma"
    }
}
