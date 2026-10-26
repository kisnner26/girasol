import SwiftUI
import SunKit

/// brujula de sombra: gira la muñeca hasta que la marca de sol quede detras de ti.
struct ShadeCompassView: View {
    @Environment(AppModel.self) private var model
    @State private var heading = HeadingService()
    @State private var aligned = false

    var body: some View {
        VStack(spacing: 8) {
            if let target = model.shadeHeading {
                Caption("gira hasta dar la espalda al sol")
                ZStack {
                    Circle().stroke(Palette.faint, lineWidth: 0.8)
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle().fill(Palette.ink.opacity(0.35)).frame(width: 0.7, height: 6)
                            .offset(y: -58).rotationEffect(.degrees(Double(i) * 90))
                    }
                    // marca fija: hacia donde apunta la muñeca ahora mismo
                    Rectangle().fill(Palette.ink).frame(width: 1.2, height: 14).offset(y: -58)

                    // el sol, en relacion a hacia donde apuntas
                    Text("✦").font(.serif(16)).foregroundStyle(Palette.olive)
                        .offset(y: -50)
                        .rotationEffect(.degrees(relativeBearing(sunAzimuth(target), heading.heading)))

                    // el objetivo: donde debe quedar tu espalda
                    Circle().strokeBorder(aligned ? Palette.moss : Palette.rose, lineWidth: 1.6)
                        .frame(width: 14, height: 14)
                        .offset(y: -50)
                        .rotationEffect(.degrees(relativeBearing(target, heading.heading)))

                    Circle().fill(Palette.ink).frame(width: 4, height: 4)
                }
                .frame(width: 128, height: 128)
                .padding(.vertical, 4)

                Text(aligned ? "ya le das la espalda al sol" : "sigue girando").font(.serif(13, italic: true))
                    .foregroundStyle(aligned ? Palette.moss : Palette.mid)
                if !heading.available {
                    Text("este reloj no tiene brújula").font(.serif(10, italic: true)).foregroundStyle(Palette.rose)
                }
            } else {
                EmptyState()
            }
        }
        .padding(.horizontal, 8)
        .paperBackground()
        .onAppear { heading.start() }
        .onDisappear { heading.stop() }
        .onChange(of: heading.heading) { _, new in checkAlignment(new) }
    }

    private func sunAzimuth(_ shade: Double) -> Double { fmod(shade + 180, 360) }

    /// cuanto hay que rotar la marca, en la pantalla, para que quede relativa a hacia donde apuntas ahora.
    private func relativeBearing(_ target: Double, _ current: Double) -> Double {
        fmod(target - current + 360, 360)
    }

    private func checkAlignment(_ current: Double) {
        guard let target = model.shadeHeading else { return }
        let diff = abs(relativeBearing(target, current) > 180 ? relativeBearing(target, current) - 360 : relativeBearing(target, current))
        let close = diff < 10
        if close != aligned {
            aligned = close
            if close { Haptics.play(.success) }
        }
    }
}
