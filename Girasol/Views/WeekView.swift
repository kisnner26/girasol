import SwiftUI
import HealthCore

/// racha de dias con agua, pasos y sol dentro de tu limite, y los ultimos 7 dias de un vistazo.
struct WeekView: View {
    @Environment(HealthModel.self) private var health

    var body: some View {
        let week = Streaks.week(health.history, today: health.now)
        let streak = health.streak
        ScrollView {
            VStack(spacing: 6) {
                Caption("racha")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(streak)").font(.serif(44)).foregroundStyle(Palette.ink)
                    Text(streak == 1 ? "día" : "días").font(.serif(14, italic: true)).foregroundStyle(Palette.mid)
                }
                Text("con agua, pasos y sol dentro de tu límite").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                    .multilineTextAlignment(.center)
                Hairline().padding(.vertical, 4)

                HStack(spacing: 0) {
                    ForEach(week.indices, id: \.self) { i in
                        column(week[i].day, week[i].record, isToday: i == week.count - 1)
                    }
                }
                HStack(spacing: 10) {
                    key("agua", Palette.moss); key("pasos", Palette.olive); key("sol", Palette.rose); key("calma", Palette.ink)
                }
                .padding(.top, 2)

                Hairline().padding(.vertical, 4)
                Text("mejor racha: \(health.bestStreak)").font(.serif(12, italic: true)).foregroundStyle(Palette.ink)
                Text("cuenta lo que guarda Salud en los últimos 7 días; el sol lo mide Girasol cuando la abres.")
                    .font(.serif(9, italic: true)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)

                if let r = health.weeklyReport {
                    Hairline().padding(.vertical, 4)
                    WeeklyReportBlock(report: r, profile: health.profile)
                }
            }
            .padding(.horizontal, 6)
        }
        .paperBackground()
        .task { await health.refreshHabits() }
    }

    private func column(_ day: Date, _ r: DayRecord?, isToday: Bool) -> some View {
        VStack(spacing: 5) {
            dot(r?.waterMet, Palette.moss)
            dot(r?.stepsMet, Palette.olive)
            dot(r.map { $0.sunFraction == nil ? nil : $0.sunMet } ?? nil, Palette.rose)
            dot(r.map { $0.mindfulGoal > 0 ? $0.mindfulMet : nil } ?? nil, Palette.ink)
            Text(initial(day)).font(.serif(9, italic: isToday)).foregroundStyle(isToday ? Palette.ink : Palette.mid)
        }
        .frame(maxWidth: .infinity)
    }

    /// lleno = cumplido, hueco = no, punto pequeño = sin dato.
    @ViewBuilder private func dot(_ met: Bool?, _ color: Color) -> some View {
        switch met {
        case true?: Circle().fill(color).frame(width: 9, height: 9)
        case false?: Circle().stroke(color, lineWidth: 1).frame(width: 9, height: 9)
        case nil: Circle().fill(Palette.faint).frame(width: 3, height: 3).frame(width: 9, height: 9)
        }
    }

    private func initial(_ d: Date) -> String {
        let cal = Lang.calendar
        return cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }

    private func key(_ text: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text).font(.serif(9, italic: true)).foregroundStyle(Palette.mid)
        }
    }
}

/// "esta semana bebiste X, dormiste Y": el promedio diario contra la semana anterior, sin sacar conclusiones de causa.
struct WeeklyReportBlock: View {
    let report: WeeklyReport
    let profile: Profile

    var body: some View {
        VStack(spacing: 4) {
            Caption("esta semana")
            Text(profile.volumeUnit.text(ml: report.waterMl) + " " + loc("de agua al día") + " " + deltaText(report.waterDeltaMl, unit: "ml"))
                .font(.serif(11, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text("\(numberText(Double(report.steps))) " + loc("pasos al día") + " " + deltaText(report.stepsDelta, unit: ""))
                .font(.serif(11, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            if report.hasSleepData {
                Text(String(format: "%.1f", report.sleepHours) + " " + loc("h de sueño") + " " + deltaText(report.sleepDeltaHours, unit: "h", decimals: 1))
                    .font(.serif(11, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            }
            Text("comparado con la semana anterior; no dice que uno cause el otro.")
                .font(.serif(9, italic: true)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)
        }
    }

    private func deltaText(_ delta: Int, unit: String) -> String {
        deltaText(Double(delta), unit: unit, decimals: 0)
    }

    private func deltaText(_ delta: Double, unit: String, decimals: Int) -> String {
        guard abs(delta) >= (decimals == 0 ? 1 : 0.1) else { return loc("(igual que antes)") }
        let value = decimals == 0 ? "\(Int(abs(delta).rounded()))" : String(format: "%.\(decimals)f", abs(delta))
        let text = unit.isEmpty ? value : "\(value) \(unit)"
        return delta > 0 ? loc("(+\(text) que antes)") : loc("(-\(text) que antes)")
    }
}
