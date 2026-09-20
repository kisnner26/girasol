import SwiftUI
import HealthCore

/// las horas que dormiste, la ultima semana y como se relacionan con el agua y los pasos.
struct SleepView: View {
    @Environment(HealthModel.self) private var health

    var body: some View {
        let p = health.profile
        ScrollView {
            VStack(spacing: 6) {
                Caption("sueño")
                if let n = health.lastNight {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", n.hours)).font(.serif(40)).foregroundStyle(Palette.ink)
                        Text("h").font(.serif(14, italic: true)).foregroundStyle(Palette.mid)
                    }
                    Text(n.hours >= Sleep.goalHours ? "descansaste lo que necesitas" : "menos de \(Int(Sleep.goalHours)) h")
                        .font(.serif(12, italic: true)).foregroundStyle(n.hours >= Sleep.goalHours ? Palette.moss : Palette.rose)
                    Hairline().padding(.vertical, 3)
                    bars
                    Hairline().padding(.vertical, 3)
                    insight(p)
                } else {
                    Text("sin datos de sueño").font(.serif(15, italic: true)).foregroundStyle(Palette.ink).padding(.top, 8)
                    Text("duerme con el reloj puesto y activa el seguimiento de sueño en la app Sueño del iPhone.")
                        .font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                }
                Button("actualizar") { Task { await health.refreshHabits() } }.buttonStyle(QuietButtonStyle()).padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
        .task { await health.refreshHabits() }
    }

    private var bars: some View {
        let nights = health.nights
        let top = max(Sleep.goalHours + 1, nights.map(\.hours).max() ?? 0)
        return VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(nights.indices, id: \.self) { i in
                    let n = nights[i]
                    VStack(spacing: 2) {
                        Capsule().fill(n.hours >= Sleep.goalHours ? Palette.ink : (n.hours > 0 ? Palette.mid : Palette.faint))
                            .frame(width: 8, height: max(2, 44 * n.hours / top))
                        Text(initial(n.day)).font(.serif(8)).foregroundStyle(Palette.mid)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 58, alignment: .bottom)
            Caption("meta \(Int(Sleep.goalHours)) h")
        }
    }

    @ViewBuilder private func insight(_ p: Profile) -> some View {
        if let i = health.sleepInsight {
            VStack(spacing: 4) {
                Caption("con \(Int(Sleep.goalHours)) h o más")
                Text(line(water: i.waterDifferenceMl, steps: i.stepsDifference, unit: p.volumeUnit))
                    .font(.serif(12, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                Text("\(i.restedDays) días descansados frente a \(i.shortDays) cortos. es una comparación, no una causa.")
                    .font(.serif(9, italic: true)).foregroundStyle(Palette.faint).multilineTextAlignment(.center)
            }
        } else {
            Text("necesito más noches con datos para comparar el sueño con tu agua y tus pasos.")
                .font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
        }
    }

    private func line(water: Int, steps: Int, unit: VolumeUnit) -> String {
        let w = unit.text(ml: abs(water))
        let s = abs(steps).formatted()
        let wText = water >= 0 ? loc("bebes \(w) más") : loc("bebes \(w) menos")
        let sText = steps >= 0 ? loc("caminas \(s) pasos más") : loc("caminas \(s) pasos menos")
        return loc("\(wText) y \(sText)")
    }

    private func initial(_ d: Date) -> String {
        let cal = Lang.calendar
        return cal.veryShortWeekdaySymbols[cal.component(.weekday, from: d) - 1]
    }
}
