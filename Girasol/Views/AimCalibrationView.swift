import SwiftUI
import GameCore

/// calibracion de puntería en tres pasos: quieto, inclinar a la izquierda, inclinar hacia arriba.
/// los ejes del reloj cambian segun la muñeca y el lado de la corona, por eso se aprenden aqui.
struct AimCalibrationView: View {
    private enum Step: Int { case neutral, left, up, done, failed }

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.neutral
    @State private var neutral: Attitude?
    @State private var left: Attitude?
    @State private var latest = Attitude(roll: 0, pitch: 0, yaw: 0)
    private let settings = MotionSettings.shared

    var body: some View {
        VStack(spacing: 8) {
            Caption("puntería")
            switch step {
            case .neutral: page("1 de 3", "sostén el reloj como para jugar y quédate quieto.", "listo") { neutral = latest; step = .left }
            case .left: page("2 de 3", "inclina la muñeca hacia la izquierda, hasta donde apuntarías.", "así") { left = latest; step = .up }
            case .up: page("3 de 3", "vuelve al centro e inclina hacia arriba.", "así") { finish(up: latest) }
            case .done:
                Text("✦").font(.serif(24)).foregroundStyle(Palette.ink)
                Text("puntería lista").font(.serif(16, italic: true)).foregroundStyle(Palette.ink)
                Button("volver") { dismiss() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
            case .failed:
                Text("no se notó el movimiento").font(.serif(14, italic: true)).foregroundStyle(Palette.rose).multilineTextAlignment(.center)
                Text("inclina más la muñeca en cada paso.").font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Button("reintentar") { step = .neutral }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .keepAwake()
        .onAppear { MotionService.shared.start(hz: 30) { latest = $0.attitude } }
        .onDisappear { MotionService.shared.stop() }
    }

    private func page(_ n: LocalizedStringKey, _ text: LocalizedStringKey, _ button: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Caption(n, color: Palette.mid)
            Text(text).font(.serif(13, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(button) { Haptics.play(.click); action() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
        }
    }

    private func finish(up: Attitude) {
        guard let n = neutral, let l = left, let m = AimMapping.calibrate(neutral: n, left: l, up: up) else {
            Haptics.play(.failure); step = .failed; return
        }
        settings.mapping = m
        Haptics.play(.success)
        step = .done
    }
}
