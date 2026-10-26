import SwiftUI
import HealthCore

/// aviso de modo viaje en el inicio: propone subir la meta de agua tras un cambio grande de zona horaria, o recuerda que esta activo.
struct TravelCard: View {
    @Environment(HealthModel.self) private var health

    var body: some View {
        if let shift = health.travelShift {
            VStack(spacing: 4) {
                Caption("viaje")
                Text(loc("cambió tu zona horaria (\(String(format: "%+d h", shift))). puedes subir tu meta de agua \(percent) durante \(TravelMode.durationDays) días mientras te adaptas."))
                    .font(.serif(11, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                Button("subir la meta") { Task { await health.acceptTravel() } }.buttonStyle(InkButtonStyle())
                Button("ahora no") { health.dismissTravel() }.buttonStyle(QuietButtonStyle())
                Hairline(opacity: 0.2).padding(.top, 2)
            }
            .padding(.vertical, 4)
        } else if let boost = health.travel {
            VStack(spacing: 3) {
                Caption("modo viaje")
                Text(loc("meta de agua \(percent) hasta el \(until(boost))"))
                    .font(.serif(11, italic: true)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                Button("terminar") { Task { await health.endTravel() } }.buttonStyle(QuietButtonStyle())
                Hairline(opacity: 0.2).padding(.top, 2)
            }
            .padding(.vertical, 4)
        }
    }

    private var percent: String { "+\(Int((TravelMode.boostFraction * 100).rounded())) %" }

    private func until(_ boost: TravelMode.Boost) -> String {
        boost.until.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Lang.locale))
    }
}
