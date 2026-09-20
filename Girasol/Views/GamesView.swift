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

/// puntaje y tiempo arriba, debajo del reloj del sistema.
struct GameHUD: View {
    let left: LocalizedStringKey
    let right: LocalizedStringKey
    var body: some View {
        HStack {
            Caption(left, color: Palette.ink)
            Spacer()
            Caption(right, color: Palette.ink)
        }
        .padding(.horizontal, 12).padding(.top, 22)
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
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
