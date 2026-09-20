import SwiftUI

/// un petalo: elipse alargada que arranca fuera del centro, girada `index` pasos.
struct Petal: Shape {
    let index: Int
    let count: Int
    let length: CGFloat   // fraccion del radio

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let inner = r * 0.36
        let outer = r * length
        let w = r * 0.15
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - w, y: c.y - outer, width: 2 * w, height: outer - inner))
        let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
        return p.applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle).translatedBy(x: -c.x, y: -c.y))
    }
}

/// el indice uv como un girasol de trazo: un petalo entintado por cada punto de uv.
struct SunflowerGauge: View {
    let uvi: Double
    var petals = 12

    private var filled: Int { uvi <= 0 ? 0 : min(petals, Int(uvi.rounded(.up))) }
    private var length: CGFloat { 0.86 + 0.14 * CGFloat(min(uvi, 11) / 11) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<petals, id: \.self) { i in
                    if i < filled {
                        Petal(index: i, count: petals, length: length).fill(Palette.ink.opacity(0.9))
                    }
                    Petal(index: i, count: petals, length: length)
                        .stroke(Palette.ink.opacity(i < filled ? 1 : 0.32), lineWidth: 0.9)
                }
                Circle().fill(Palette.paper).frame(width: side * 0.42, height: side * 0.42)
                Circle().stroke(Palette.ink, lineWidth: 1).frame(width: side * 0.36, height: side * 0.36)
                ForEach(0..<10, id: \.self) { d in
                    Circle().fill(Palette.ink.opacity(0.4)).frame(width: 1.4, height: 1.4)
                        .offset(y: -side * 0.2)
                        .rotationEffect(.degrees(Double(d) * 36))
                }
                Text(uvi.uvText)
                    .font(.serif(side * 0.17))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.6)
                    .frame(width: side * 0.28)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("índice uv \(uvi.uvText)")
    }
}

/// ramito de linea fina para los estados vacios.
struct Sprig: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 60, size.height / 84)
            ctx.translateBy(x: (size.width - 60 * s) / 2, y: (size.height - 84 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            let style = StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
            var stem = Path()
            stem.move(to: .init(x: 30, y: 82)); stem.addCurve(to: .init(x: 30, y: 28), control1: .init(x: 29, y: 64), control2: .init(x: 31, y: 46))
            ctx.stroke(stem, with: .color(Palette.ink), style: style)
            for k in 0..<5 {
                var p = Path()
                p.addEllipse(in: CGRect(x: -4.5, y: -10, width: 9, height: 20))
                let t = CGAffineTransform(translationX: 30, y: 20).rotated(by: CGFloat(k) * 2 * .pi / 5)
                ctx.stroke(p.applying(t), with: .color(Palette.ink), style: style)
            }
            ctx.stroke(Path(ellipseIn: CGRect(x: 26.6, y: 16.6, width: 6.8, height: 6.8)), with: .color(Palette.ink), style: style)
            var leaf1 = Path()
            leaf1.move(to: .init(x: 30, y: 58)); leaf1.addCurve(to: .init(x: 16, y: 39), control1: .init(x: 20, y: 54), control2: .init(x: 14, y: 46))
            leaf1.addCurve(to: .init(x: 30, y: 58), control1: .init(x: 25, y: 39), control2: .init(x: 30, y: 47))
            var leaf2 = Path()
            leaf2.move(to: .init(x: 30, y: 66)); leaf2.addCurve(to: .init(x: 44, y: 49), control1: .init(x: 39, y: 63), control2: .init(x: 45, y: 56))
            leaf2.addCurve(to: .init(x: 30, y: 66), control1: .init(x: 36, y: 50), control2: .init(x: 30, y: 57))
            ctx.stroke(leaf1, with: .color(Palette.ink), style: style)
            ctx.stroke(leaf2, with: .color(Palette.ink), style: style)
        }
        .accessibilityHidden(true)
    }
}
