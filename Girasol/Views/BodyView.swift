import SwiftUI
import HealthCore

struct BodyView: View {
    @Environment(HealthModel.self) private var health

    var body: some View {
        let p = health.profile
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Caption("cuerpo · hoy").frame(maxWidth: .infinity)

                metric("pasos", numberText(health.totals.steps), loc("de \(p.stepGoal.formatted())")) {
                    Ring(fraction: health.stepsFraction, tint: Palette.moss, width: 3).frame(width: 30, height: 30)
                }

                metric("pulso", health.heart.latest.map { loc("\(Int($0.rounded())) lpm") } ?? "—",
                       [health.heart.latestDate.map { loc("a las \(hourMinute($0))") },
                        health.heart.resting.map { loc("en reposo \(Int($0.rounded())) · \(RestingHeart.title(bpm: $0))") }]
                        .compactMap { $0 }.joined(separator: "\n")) { LineIcon(kind: .heart).frame(width: 26, height: 26) }

                oxygenBlock

                Text("actividad: \(numberText(health.totals.activeKcal)) kcal activas · \(Int(health.totals.mindfulMinutes.rounded())) min de calma")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid)

                Text("estos datos son orientativos y no sustituyen a un médico.")
                    .font(.serif(9, italic: true)).foregroundStyle(Palette.faint)
                Button("actualizar") { Task { await health.refresh() } }.buttonStyle(InkButtonStyle()).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
    }

    @ViewBuilder private var oxygenBlock: some View {
        if let o = health.latestOxygen {
            let level = OxygenLevel(percent: o.percent)
            let color: Color = level == .normal ? Palette.moss : level == .watch ? Palette.olive : Palette.rose
            metric("oxígeno en sangre", "\(Int(o.percent.rounded())) %", "\(level.title) · \(hourMinute(o.date))") {
                Circle().stroke(color, lineWidth: 2).frame(width: 22, height: 22)
            }
            Text(level.message).font(.serif(10, italic: true)).foregroundStyle(color)
            if health.oxygen.count > 1 {
                let avg = health.oxygen.map(\.percent).reduce(0, +) / Double(health.oxygen.count)
                Caption("48 h · promedio \(Int(avg.rounded())) % · \(health.oxygen.count) mediciones")
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Caption("oxígeno en sangre")
                Text("sin mediciones en 48 h").font(.serif(14, italic: true)).foregroundStyle(Palette.ink)
                Text("ábrela con la app Oxígeno del reloj, quieto y en reposo. Apple no permite que otra app inicie la medición.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
            }
        }
    }

    private func metric<V: View>(_ title: LocalizedStringKey, _ value: String, _ detail: String, @ViewBuilder icon: () -> V) -> some View {
        HStack(spacing: 10) {
            icon()
            VStack(alignment: .leading, spacing: 1) {
                Caption(title)
                Text(value).font(.serif(20)).foregroundStyle(Palette.ink)
                if !detail.isEmpty { Text(detail).font(.serif(10, italic: true)).foregroundStyle(Palette.mid) }
            }
        }
    }
}
