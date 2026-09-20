import SwiftUI
import GameCore

/// calibracion de puntería sin pulsar nada: quieto, inclinar a la izquierda, volver al centro e inclinar hacia arriba.
/// cada postura se captura sola cuando el reloj se queda quieto en ella (pulsar un botón movía la muñeca).
struct AimCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calibrator = AimCalibrator()
    @State private var lastCaptures = 0
    @State private var attempt = 0
    private let settings = MotionSettings.shared

    var body: some View {
        VStack(spacing: 8) {
            Caption("puntería")
            switch calibrator.state {
            case .running(let step): running(step)
            case .done:
                Text("✦").font(.serif(24)).foregroundStyle(Palette.ink)
                Text("puntería lista").font(.serif(16, italic: true)).foregroundStyle(Palette.ink)
                Button("volver") { dismiss() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
            case .failed(let reason):
                Text(title(reason)).font(.serif(14, italic: true)).foregroundStyle(Palette.rose).multilineTextAlignment(.center)
                Text(hint(reason)).font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Button("reintentar") { restart() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .keepAwake()
        .onAppear { start() }
        .onDisappear { MotionService.shared.stop() }
    }

    // MARK: pasos

    private func running(_ step: AimCalibrator.Step) -> some View {
        VStack(spacing: 8) {
            Caption(verbatim: "\(step.rawValue + 1)/3", color: Palette.mid)
            Text(instruction(step)).font(.serif(13, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            gauge(step)
            Text(subtitle(step)).font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
        }
    }

    /// el anillo se llena mientras te quedas quieto; la barra de abajo muestra cuanto has inclinado.
    private func gauge(_ step: AimCalibrator.Step) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Palette.faint, lineWidth: 3)
                Circle().trim(from: 0, to: calibrator.hold).stroke(Palette.moss, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 44, height: 44)
            if step != .neutral {
                GeometryReader { g in
                    let full = g.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.faint).frame(height: 4)
                        Capsule().fill(calibrator.angle >= AimMapping.minAngle ? Palette.moss : Palette.olive)
                            .frame(width: min(full, full * calibrator.angle / 0.4), height: 4)
                        Rectangle().fill(Palette.ink).frame(width: 1, height: 9)
                            .offset(x: full * AimMapping.minAngle / 0.4)
                    }
                }
                .frame(width: 100, height: 9)
            }
        }
    }

    private func instruction(_ step: AimCalibrator.Step) -> LocalizedStringKey {
        switch step {
        case .neutral: "sostén el reloj como para jugar y quédate quieto."
        case .left: "inclina la muñeca hacia la izquierda y quédate quieto."
        case .up: "vuelve al centro, inclina hacia arriba y quédate quieto."
        }
    }

    private func subtitle(_ step: AimCalibrator.Step) -> LocalizedStringKey {
        switch step {
        case .neutral: "se fija solo"
        case .left, .up: "llega hasta la marca de la barra"
        }
    }

    private func title(_ r: AimCalibrator.Reason) -> LocalizedStringKey {
        switch r {
        case .tooLittleMovement: "no se notó el movimiento"
        case .notStill: "no te quedaste quieto"
        case .sameDirection: "izquierda y arriba fueron iguales"
        }
    }

    private func hint(_ r: AimCalibrator.Reason) -> LocalizedStringKey {
        switch r {
        case .tooLittleMovement: "inclina más la muñeca en cada paso."
        case .notStill: "al llegar a la postura, aguanta medio segundo sin moverte."
        case .sameDirection: "el segundo giro tiene que ser hacia arriba, no otra vez hacia la izquierda."
        }
    }

    // MARK: flujo

    private func start() {
        calibrator = AimCalibrator()
        lastCaptures = 0
        MotionService.shared.start(hz: 30) { sample in
            calibrator.feed(sample)
            if calibrator.captures != lastCaptures {
                lastCaptures = calibrator.captures
                Haptics.play(calibrator.state == .done ? .success : .click)
            }
            switch calibrator.state {
            case .done:
                if let m = calibrator.mapping { settings.mapping = m }
                MotionService.shared.stop()
            case .failed:
                Haptics.play(.failure)
                MotionService.shared.stop()
            case .running:
                break
            }
        }
    }

    private func restart() {
        MotionService.shared.stop()
        start()
    }
}
