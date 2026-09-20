import SwiftUI
import SunKit

struct ExposureView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let s = model.summary {
                let f = s.fraction
                let tint: Color = s.stage == .none ? Palette.moss : s.stage == .approaching ? Palette.olive : Palette.rose
                VStack(spacing: 6) {
                    Caption("exposición de hoy")
                    ZStack {
                        Circle().stroke(Palette.faint, lineWidth: 0.7)
                        ForEach(0..<4, id: \.self) { i in
                            Rectangle().fill(Palette.ink.opacity(0.45)).frame(width: 0.7, height: 5)
                                .offset(y: -57).rotationEffect(.degrees(Double(i) * 90))
                        }
                        Circle().trim(from: 0, to: min(1, f))
                            .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(Int((f * 100).rounded()))").font(.serif(36)).foregroundStyle(Palette.ink)
                                Text("%").font(.serif(14, italic: true)).foregroundStyle(Palette.mid)
                            }
                            Text("de tu límite").font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
                        }
                    }
                    .frame(width: 124, height: 124)
                    .padding(.vertical, 2)

                    Text(status(s.stage)).font(.serif(15, italic: true)).foregroundStyle(tint)
                    Hairline().padding(.vertical, 2)
                    if s.daylightMinutes > 0 {
                        Caption("\(minutesText(s.daylightMinutes)) al aire libre")
                    } else {
                        Text("sin minutos al aire libre registrados hoy").font(.serif(11, italic: true))
                            .foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                    }
                    if model.sunNow { Caption("✦ al sol ahora", color: Palette.ink) }
                }
                .padding(.horizontal, 6)
            } else {
                EmptyState()
            }
        }
        .containerBackground(Palette.paper, for: .tabView)
    }

    private func status(_ stage: LimitStage) -> String {
        switch stage {
        case .none: "dentro de lo seguro"
        case .approaching: "cerca del límite"
        case .reached: "límite superado"
        }
    }
}
