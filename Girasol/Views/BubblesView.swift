import SwiftUI
import GameCore

/// pompas para desestresar: sin tiempo, sin puntaje que perder.
struct BubblesView: View {
    @State private var game = Bubbles(seed: UInt64(Date().timeIntervalSince1970))
    @State private var clock = FrameClock()
    @State private var lastPop: Date?
    @AppStorage("girasol.popped.total") private var total = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { _ in
                    Canvas { ctx, size in draw(&ctx, size) }
                }
                VStack {
                    Spacer()
                    Caption(game.popped == 0 ? "toca las pompas" : "reventadas · \(game.popped)", color: Palette.ink)
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }
            .gameLoop { game.step(dt: clock.dt($0)) }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in tap(v.location, geo.size) })
        }
        .paperBackground()
        .keepAwake()
        .onDisappear { clock.reset() }
    }

    private func tap(_ point: CGPoint, _ size: CGSize) {
        // un solo golpe por toque: pop() ya la retira, asi que arrastrar el dedo revienta varias seguidas
        if game.pop(at: Vec(x: point.x / size.width, y: 1 - point.y / size.height)) != nil {
            total += 1
            Haptics.play(.click)
            Sfx.shared.play(.pop)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        for b in game.bubbles {
            let c = CGPoint(x: b.x(at: game.elapsed) * w, y: (1 - b.y) * h)
            let r = b.radius * w
            let circle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(circle, with: .color(Palette.ink.opacity(0.05)))
            ctx.stroke(circle, with: .color(Palette.ink.opacity(0.85)), lineWidth: 1)
            var shine = Path()
            shine.addArc(center: c, radius: r * 0.65, startAngle: .degrees(200), endAngle: .degrees(260), clockwise: false)
            ctx.stroke(shine, with: .color(Palette.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }
}
