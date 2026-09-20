import SwiftUI
import HealthCore

/// bienvenida: nombre, permiso de Salud y metas sugeridas. tres pasos cortos.
struct OnboardingView: View {
    @Environment(HealthModel.self) private var health
    @State private var step = 0
    @State private var busy = false

    var body: some View {
        @Bindable var store = health.profiles
        ScrollView {
            VStack(spacing: 10) {
                switch step {
                case 0:
                    Sprig().frame(width: 52, height: 72)
                    Text("girasol").font(.serif(24, italic: true)).tracking(4).foregroundStyle(Palette.ink)
                    Text("sol, agua, calma y salud en tu muñeca").font(.serif(12, italic: true)).foregroundStyle(Palette.mid)
                        .multilineTextAlignment(.center)
                    Button("empezar") { step = 1 }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
                case 1:
                    Caption("hola")
                    Text("¿cómo te llamas?").font(.serif(16, italic: true)).foregroundStyle(Palette.ink)
                    NameField(name: $store.profile.name)
                    Button("siguiente") { step = 2 }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
                case 2:
                    Caption("tu salud")
                    Text("para calcular tus metas leo de Salud tu peso, estatura y edad; también tus pasos, pulso y oxígeno. no sale de tu reloj.")
                        .font(.serif(12, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                    Button(busy ? "…" : "permitir") {
                        busy = true
                        Task {
                            await health.requestAccess()
                            await health.importBody()
                            busy = false
                            step = 3
                        }
                    }
                    .buttonStyle(InkButtonStyle()).disabled(busy).doubleTapPrimary()
                    Button("ahora no") { step = 3 }.buttonStyle(QuietButtonStyle())
                default:
                    Caption(health.profile.displayName.isEmpty ? "tus metas" : "tus metas, \(health.profile.displayName)")
                    let water = health.suggestedWaterGoal()
                    let kcal = health.suggestedKcalGoal() ?? health.profile.kcalGoal
                    goal("agua", VolumeUnit.ml.text(ml: water))
                    goal("comida", "\(kcal) kcal")
                    goal("pasos", health.profile.stepGoal.formatted())
                    Text("las cambias cuando quieras en ajustes.").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                    Button("listo") {
                        var p = health.profile
                        p.waterGoalMl = water
                        p.kcalGoal = kcal
                        p.onboarded = true
                        health.profiles.profile = p
                    }
                    .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }
        .background(Palette.paper.ignoresSafeArea())
        .paperBackground()
    }

    private func goal(_ title: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Caption(title)
            Text(value).font(.serif(20)).foregroundStyle(Palette.ink)
        }
    }
}
