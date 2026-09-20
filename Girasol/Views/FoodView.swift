import SwiftUI
import HealthCore

struct FoodView: View {
    @Environment(HealthModel.self) private var health
    @State private var amount = 250.0

    var body: some View {
        let p = health.profile
        let over = health.kcalRemaining < 0
        VStack(spacing: 5) {
            Caption("comida · hoy")
            ZStack {
                Ring(fraction: health.kcalFraction, tint: over ? Palette.rose : Palette.olive, width: 4)
                VStack(spacing: 0) {
                    Text(numberText(health.totals.foodKcal)).font(.serif(22)).foregroundStyle(Palette.ink)
                    Text("kcal").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                }
            }
            .frame(width: 74, height: 74)
            Text(over ? "\(-health.kcalRemaining) kcal de más" : "te quedan \(health.kcalRemaining) kcal")
                .font(.serif(12, italic: true)).foregroundStyle(over ? Palette.rose : Palette.mid)
            if p.addActivityToKcal, health.totals.activeKcal >= 1 {
                Caption("+ \(numberText(health.totals.activeKcal)) por actividad")
            }
            Text("+ \(Int(amount)) kcal").font(.serif(18)).foregroundStyle(Palette.ink)
            Button("añadir") { Task { await health.addFood(Int(amount)) } }
                .buttonStyle(InkButtonStyle()).doubleTapPrimary()
            Button("deshacer el último") { Task { await health.undoFood() } }.buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 8)
        .focusable()
        .digitalCrownRotation($amount, from: 50, through: 1500, by: 50, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .paperBackground()
    }
}
