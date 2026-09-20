import SwiftUI
import HealthCore

/// vaso de trazo que se llena segun el progreso; el nivel lleva una onda suave.
struct GlassGauge: View {
    let fraction: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { tl in
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let topInset: CGFloat = 0, bottomInset: CGFloat = w * 0.16
                var glass = Path()
                glass.move(to: CGPoint(x: topInset, y: 1))
                glass.addLine(to: CGPoint(x: w - topInset, y: 1))
                glass.addLine(to: CGPoint(x: w - bottomInset, y: h - 1))
                glass.addLine(to: CGPoint(x: bottomInset, y: h - 1))
                glass.closeSubpath()

                let level = h - (h - 8) * CGFloat(min(1, max(0, fraction))) - 2
                var water = Path()
                let t = tl.date.timeIntervalSinceReferenceDate
                water.move(to: CGPoint(x: 0, y: h))
                var x: CGFloat = 0
                while x <= w {
                    water.addLine(to: CGPoint(x: x, y: level + 1.5 * sin(x / w * 6 + t * 1.6)))
                    x += 2
                }
                water.addLine(to: CGPoint(x: w, y: h))
                water.closeSubpath()

                ctx.drawLayer { layer in
                    layer.clip(to: glass)
                    if fraction > 0 { layer.fill(water, with: .color(Palette.moss.opacity(0.55))) }
                }
                ctx.stroke(glass, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            }
        }
        .accessibilityLabel("vaso al \(Int(fraction * 100)) %")
    }
}

struct WaterView: View {
    @Environment(HealthModel.self) private var health
    @State private var amount = 250.0

    var body: some View {
        let p = health.profile
        VStack(spacing: 5) {
            Caption("agua · hoy")
            HStack(spacing: 12) {
                GlassGauge(fraction: health.waterFraction).frame(width: 40, height: 56)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.volumeUnit.text(ml: health.totals.waterMl)).font(.serif(21)).foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text("de \(p.volumeUnit.text(ml: p.waterGoalMl))").font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
                    Caption(String(format: "≈ %.1f vasos", Hydration.glasses(ml: health.totals.waterMl, glassMl: p.glassMl)))
                }
            }
            Hairline().padding(.vertical, 2)
            Text("+ \(p.volumeUnit.text(ml: Int(amount)))").font(.serif(19)).foregroundStyle(Palette.ink)
            Caption("gira la corona")
            Button("añadir") { Task { await health.addWater(Int(amount)) } }
                .buttonStyle(InkButtonStyle()).doubleTapPrimary()
            Button("deshacer el último") { Task { await health.undoWater() } }.buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 8)
        .focusable()
        .digitalCrownRotation($amount, from: 50, through: 1000, by: 50, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear { amount = Double(p.glassMl) }
        .paperBackground()
    }
}
