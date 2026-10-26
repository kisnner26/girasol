import SwiftUI
import SunKit

struct ExposureView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let s = model.summary {
                VStack(spacing: 6) {
                    Caption("exposición ambiental estimada")
                    Text(s.standardErythemaDoses, format: .number.precision(.fractionLength(1)))
                        .font(.serif(36)).foregroundStyle(Palette.ink)
                    Caption("sed estimadas")
                    if s.estimatedMinutes < s.daylightMinutes {
                        Text("estimación parcial: faltan horas del pronóstico").font(.serif(11, italic: true)).foregroundStyle(Palette.rose)
                    }
                    Text("1 sed = 100 j/m². no es una dosis segura ni una medición de tu piel.")
                        .font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                    NavigationLink { SolarMethodView() } label: { Caption("cómo se estima") }
                    HealthNotice()
                    Hairline().padding(.vertical, 2)
                    if s.daylightMinutes > 0 {
                        Caption("\(minutesText(s.daylightMinutes)) al aire libre")
                    } else {
                        Text("sin minutos al aire libre registrados hoy").font(.serif(11, italic: true))
                            .foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                    }
                    if model.sunNow { Caption("luz diurna registrada recientemente", color: Palette.ink) }
                    if model.shadeHeading != nil {
                        NavigationLink(value: Route.shadeCompass) { Caption("brújula de sombra", color: Palette.ink) }
                            .buttonStyle(.plain)
                    }
                    SunscreenTimerView()
                }
                .padding(.horizontal, 6)
            } else {
                EmptyState()
            }
        }
        .containerBackground(Palette.paper, for: .tabView)
    }


}

/// cuenta atras para reaplicar protector, o el boton para empezarla.
struct SunscreenTimerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 4) {
            Hairline().padding(.vertical, 2)
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                if let t = model.sunscreenTimer, t.isActive(at: tl.date) {
                    VStack(spacing: 4) {
                        Caption("reaplicar protector en")
                        Text(minutesText(t.remaining(at: tl.date) / 60)).font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                        Button("posponer 20 min") { Task { await model.snoozeSunscreen() } }
                            .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                        Text("doble toque pospone").font(.serif(9, italic: true)).foregroundStyle(Palette.mid)
                        Button("ya me lo reapliqué") { Task { await model.applySunscreen() } }.buttonStyle(QuietButtonStyle())
                        Button("cancelar") { Task { await model.clearSunscreen() } }.buttonStyle(QuietButtonStyle())
                    }
                } else {
                    Button("me puse protector") { Task { await model.applySunscreen() } }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
                    Text("te aviso a las 2 h").font(.serif(10, italic: true)).foregroundStyle(Palette.mid)
                }
            }
        }
    }
}
