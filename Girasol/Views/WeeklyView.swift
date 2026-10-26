import SwiftUI
import HealthCore

/// resumen de los ultimos 7 dias terminados frente a los 7 anteriores, con un solo mensaje.
struct WeeklyView: View {
    @Environment(HealthModel.self) private var health

    var body: some View {
        let s = WeeklySummary.make(records: health.history, nights: health.nights, today: health.now)
        let c = s.current
        let p = health.profile
        ScrollView {
            VStack(spacing: 6) {
                Caption("resumen semanal")
                Text(message(s.highlight)).font(.serif(13, italic: true)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Hairline().padding(.vertical, 3)

                if c.daysWithData > 0 {
                    stat("agua", p.volumeUnit.text(ml: c.avgWaterMl), detail: loc("\(c.waterGoalDays) de \(c.daysWithData) días con tu meta"), trend: s.waterTrend)
                    stat("pasos", numberText(Double(c.avgSteps)), detail: loc("\(c.stepsGoalDays) de \(c.daysWithData) días con tu meta"), trend: s.stepsTrend)
                    if let sleep = c.avgSleepHours {
                        stat("sueño", loc("\(String(format: "%.1f", sleep)) h por noche"), detail: nil, trend: .unknown)
                    }
                    stat("días completos", loc("\(c.perfectDays) de \(c.daysWithData)"), detail: loc("agua y pasos cumplidos"), trend: .unknown)
                }
                Text("promedio de los últimos 7 días terminados; hoy no cuenta. son datos de Salud, no un consejo médico.")
                    .font(.serif(9, italic: true)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .paperBackground()
        .task { await health.refreshHabits() }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, detail: String?, trend: WeeklySummary.Trend) -> some View {
        VStack(spacing: 1) {
            Caption(title)
            Text(value).font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
            if let detail { Text(detail).font(.serif(10, italic: true)).foregroundStyle(Palette.mid) }
            if let t = trendText(trend) { Text(t).font(.serif(10, italic: true)).foregroundStyle(Palette.moss) }
            Hairline(opacity: 0.2).padding(.top, 4)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func trendText(_ t: WeeklySummary.Trend) -> String? {
        switch t {
        case .up: loc("más que la semana pasada")
        case .down: loc("menos que la semana pasada")
        case .same: loc("igual que la semana pasada")
        case .unknown: nil
        }
    }

    private func message(_ h: WeeklySummary.Highlight) -> String {
        switch h {
        case .notEnoughData: loc("aún hay pocos días registrados. vuelve cuando lleves unos cuantos más.")
        case .perfectWeek: loc("semana completa: cumpliste agua y pasos todos los días registrados.")
        case .needsWater: loc("el agua fue lo más flojo esta semana. un vaso al levantarte ayuda a empezar.")
        case .needsSteps: loc("los pasos quedaron por debajo de tu meta la mayoría de los días. un paseo corto cuenta.")
        case .waterUp: loc("bebiste más que la semana anterior. sigue así.")
        case .stepsUp: loc("caminaste más que la semana anterior.")
        case .steady: loc("semana estable, muy parecida a la anterior.")
        }
    }
}
