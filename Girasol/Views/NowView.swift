import SwiftUI
import HealthCore
import SunKit

struct NowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let w = model.weather, let advice = model.advice {
                VStack(spacing: 5) {
                    Caption("ahora · \(clock(model.now, w.timeZone))")
                    SunflowerGauge(uvi: model.uvNow)
                        .frame(width: 132, height: 132)
                    Text(advice.headline)
                        .font(.serif(19, italic: true))
                        .foregroundStyle(Palette.color(for: advice.level))
                        .multilineTextAlignment(.center)
                    Text(advice.detail)
                        .font(.serif(11))
                        .foregroundStyle(Palette.mid)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Hairline().padding(.vertical, 3)
                    let unit = ProfileStore.shared.profile.temperatureUnit
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(unit.text(celsius: w.current.temperature)).font(.serif(24)).foregroundStyle(Palette.ink)
                        Text("sensación \(unit.text(celsius: w.current.apparentTemperature))").font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
                    }
                    if w.current.isDay {
                        if let m = model.safeMinutes {
                            Caption("tu piel aguanta ≈ \(minutesText(m))")
                        } else {
                            Caption("sin límite con este uv")
                        }
                    }
                    if model.isCached {
                        Caption("sin conexión · datos de \(clock(w.fetchedAt, w.timeZone))", color: Palette.rose)
                    }
                }
                .padding(.horizontal, 6)
            } else {
                EmptyState()
            }
        }
        .containerBackground(Palette.paper, for: .tabView)
    }
}

/// carga, falta de ubicacion o error, con el ramito de linea fina.
struct EmptyState: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            Sprig().frame(width: 46, height: 64).opacity(0.85)
            switch model.status {
            case .needsLocation:
                Text("necesito tu ubicación aproximada para saber el uv de donde estás")
                    .font(.serif(12, italic: true)).multilineTextAlignment(.center).foregroundStyle(Palette.mid)
                Button("permitir") { Task { await model.refresh() } }.buttonStyle(InkButtonStyle())
            case .failed(let message):
                Text(message).font(.serif(12, italic: true)).multilineTextAlignment(.center).foregroundStyle(Palette.mid)
                Button("reintentar") { Task { await model.refresh() } }.buttonStyle(InkButtonStyle())
            default:
                Text("consultando el cielo…").font(.serif(12, italic: true)).foregroundStyle(Palette.mid)
            }
        }
        .padding(.top, 14)
    }
}

/// boton en linea fina: borde de tinta, mayusculas espaciadas.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, design: .serif)).textCase(.uppercase).tracking(2)
            .foregroundStyle(configuration.isPressed ? Palette.paper : Palette.ink)
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(configuration.isPressed ? Palette.ink : Color.clear)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 0.8))
    }
}

func clock(_ date: Date, _ tz: TimeZone) -> String {
    var style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: tz)
    style.locale = Lang.locale
    return date.formatted(style)
}
