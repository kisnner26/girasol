import SwiftUI
import GameCore

struct GamesView: View {
    @AppStorage("girasol.best.airbasket") private var bestBasket = 0
    @AppStorage("girasol.best.darts") private var bestDarts = 0
    @AppStorage("girasol.best.pistol") private var bestPistol = 0
    @AppStorage("girasol.best.tennis") private var bestTennis = 0
    @AppStorage("girasol.popped.total") private var poppedTotal = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Caption("juegos")
                Text("se juegan con la muñeca").font(.serif(12, italic: true)).foregroundStyle(Palette.mid)
                    .padding(.bottom, 4)
                NavigationLink(value: Route.airBasketball) { row(.target, "baloncesto", "lanza · mejor \(bestBasket)") }
                NavigationLink(value: Route.darts) { row(.target, "dardos", "lanza · mejor \(bestDarts)") }
                NavigationLink(value: Route.pistol) { row(.target, "pistola", "apunta y dispara · mejor \(bestPistol)") }
                NavigationLink(value: Route.tennis) { row(.target, "tenis", "golpea · mejor \(bestTennis)") }
                NavigationLink(value: Route.bubbles) { row(.breath, "pompas", "\(poppedTotal) reventadas") }
                NavigationLink(value: Route.calibrate) { row(.sliders, "puntería", "calibrar la muñeca") }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .paperBackground()
        .keepAwake()
    }

    private func row(_ icon: IconKind, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HomeRow(icon: icon, title: title, detail: detail)
    }
}

/// pantalla de inicio / fin comun a los juegos con tiempo.
struct GameOverlay: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let button: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title).font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Text(subtitle).font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Caption(button, color: Palette.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.paper.opacity(0.92))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .doubleTapPrimary()
    }
}

/// puntaje y tiempo arriba, debajo del reloj del sistema; entre medio, el boton de pausa si se le pasa `onPause`.
struct GameHUD: View {
    let left: LocalizedStringKey
    let right: LocalizedStringKey
    var onPause: (() -> Void)? = nil

    var body: some View {
        HStack {
            Caption(left, color: Palette.ink).allowsHitTesting(false)
            Spacer()
            if let onPause {
                Button(action: onPause) {
                    HStack(spacing: 3) {
                        Rectangle().frame(width: 2.2, height: 10)
                        Rectangle().frame(width: 2.2, height: 10)
                    }
                    .foregroundStyle(Palette.mid)
                    .padding(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            Caption(right, color: Palette.ink).allowsHitTesting(false)
        }
        .padding(.horizontal, 12).padding(.top, 22)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// pantalla de pausa: cubre el juego entero, para el mismo boton que oculta el "volver" del sistema mientras corres.
struct PauseOverlay: View {
    let onResume: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("pausa").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
            Button("seguir", action: onResume).buttonStyle(InkButtonStyle()).doubleTapPrimary()
            Button("salir", action: onExit).buttonStyle(QuietButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.paper.opacity(0.96))
    }
}

/// avanza un juego con el reloj de pantalla: dt acotado para que una pausa no dispare la fisica.
struct FrameClock {
    private var last: Date?
    mutating func dt(_ now: Date) -> Double {
        defer { last = now }
        return min(0.05, max(0, now.timeIntervalSince(last ?? now)))
    }
    mutating func reset() { last = nil }
}
