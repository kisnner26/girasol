import SwiftUI
import GameCore

struct DartsView: View {
    @State private var game = Darts(seed: UInt64(Date().timeIntervalSince1970))
    @State private var running = false
    @State private var finished = false
    @State private var practicing = false
    @State private var practiceCount = 0
    @State private var feed = MotionFeed(threshold: MotionSettings.shared.threshold)
    @State private var flying: (from: CGPoint, to: CGPoint, score: Int, born: Date)?
    @State private var stuck: [(p: CGPoint, score: Int)] = []
    @State private var popups: [Popup] = []
    @State private var particles: [Particle] = []
    @State private var touchAim = Vec(x: 0, y: 0)
    @State private var boardSize = CGSize(width: 200, height: 240)
    @AppStorage("girasol.best.darts") private var best = 0
    private let settings = MotionSettings.shared

    private let flightTime = 0.34

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
                    Canvas { ctx, size in draw(&ctx, size, tl.date) }
                }
                GameHUD(left: "\(game.total) pts", right: running ? "ronda \(game.turn)/\(Darts.turns)" : "")
                if settings.showMeter && !settings.usesTouch && (running || practicing) {
                    MotionMeter(feed: feed, threshold: settings.threshold)
                        .padding(.horizontal, 30).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 3)
                }
                overlay
            }
            .onAppear { boardSize = geo.size }
            .gameLoop { advance($0) }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                guard settings.usesTouch, running else { return }
                let c = boardCenter(geo.size), r = boardRadius(geo.size)
                let aim = Vec(x: max(-1, min(1, (v.location.x - c.x) / r / 1.05)), y: max(-1, min(1, -(v.location.y - c.y) / r / 1.05)))
                throwDart(power: 1, aim: aim, steadiness: 1)
            })
        }
        .paperBackground()
        .keepAwake()
        .navigationBarBackButtonHidden(running)
        .onDisappear { feed.stop() }
    }

    // MARK: pantallas

    @ViewBuilder private var overlay: some View {
        if !settings.usesTouch && settings.mapping == nil && !running && !practicing {
            VStack(spacing: 8) {
                Text("dardos").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Text("primero calibra tu puntería: son 10 segundos.").font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
                    .multilineTextAlignment(.center)
                NavigationLink(value: Route.calibrate) { Caption("calibrar", color: Palette.ink) }
                    .buttonStyle(InkButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper.opacity(0.95))
        } else if practicing {
            GameOverlay(title: "calentamiento", subtitle: "tira \(PowerCalibration.needed - practiceCount) veces como un lanzamiento normal", button: "") { }
                .allowsHitTesting(false)
        } else if !running {
            GameOverlay(title: finished ? "\(game.total) puntos" : "dardos",
                        subtitle: finished ? String(format: "mejor %d · promedio %.1f por dardo", best, game.average)
                                           : (settings.usesTouch ? "toca el tablero para tirar." : "apunta inclinando la mano y lanza con la muñeca.\nsi te tiembla el pulso, el dardo se dispersa."),
                        button: finished ? "otra vez" : "empezar") { begin() }
        }
    }

    // MARK: flujo

    private func begin() {
        finished = false
        if !settings.usesTouch && !settings.dartsPower.isReady {
            practicing = true; practiceCount = 0
            startMotion()
            return
        }
        game = Darts(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        stuck = []; popups = []; particles = []; flying = nil
        running = true
        Haptics.play(.start)
        if !settings.usesTouch { startMotion() }
    }

    private func startMotion() {
        feed.start(threshold: settings.threshold) { sw in
            Sfx.shared.play(.whoosh)
            Haptics.play(.directionUp)
            if practicing {
                settings.dartsPower.add(sw.power)
                practiceCount += 1
                if settings.dartsPower.isReady { practicing = false; Haptics.play(.success); begin() }
                return
            }
            guard running else { return }
            throwDart(power: settings.dartsPower.normalized(sw.power), aim: feed.aim(at: sw.time - 0.2), steadiness: sw.steadiness)
        }
    }

    private func throwDart(power: Double, aim: Vec, steadiness: Double) {
        guard flying == nil, let l = game.throwDart(power: power, aim: aim, steadiness: steadiness) else { return }
        let c = boardCenter(boardSize), r = boardRadius(boardSize)
        let to = CGPoint(x: c.x + l.x * r, y: c.y - l.y * r)
        flying = (CGPoint(x: boardSize.width / 2, y: boardSize.height * 1.02), to, l.score, Date())
    }

    private func advance(_ now: Date) {
        guard running || flying != nil else { return }
        if let f = flying, now.timeIntervalSince(f.born) >= flightTime {
            landed(f)
            flying = nil
            if game.isOver { finishGame() }
        }
        Effects.step(&particles, dt: 1 / 60)
    }

    private func landed(_ f: (from: CGPoint, to: CGPoint, score: Int, born: Date)) {
        // el primer dardo de cada ronda recoge los anteriores
        if (game.thrown - 1) % Darts.dartsPerTurn == 0 { stuck = [] }
        stuck.append((f.to, f.score))
        Sfx.shared.play(.thunk)
        switch f.score {
        case 50: Haptics.play(.success); Sfx.shared.play(.ding); popups.append(Popup(text: "¡diana! 50", color: Palette.rose, born: Date(), big: true)); particles += Effects.burst(at: f.to, count: 14)
        case 25: Haptics.play(.success); Sfx.shared.play(.ding); popups.append(Popup(text: "25", color: Palette.moss, born: Date(), big: true))
        case 0: Haptics.play(.failure); popups.append(Popup(text: "fuera", color: Palette.rose, born: Date()))
        default:
            Haptics.play(.click)
            popups.append(Popup(text: "\(f.score)", color: f.score >= 40 ? Palette.moss : Palette.ink, born: Date(), big: f.score >= 40))
            if f.score >= 40 { Sfx.shared.play(.ding); particles += Effects.burst(at: f.to, count: 8) }
        }
        popups.removeAll { Date().timeIntervalSince($0.born) > 1.2 }
    }

    private func finishGame() {
        running = false
        finished = true
        best = max(best, game.total)
        feed.stop()
        Haptics.play(.notification)
    }

    // MARK: geometria y dibujo

    private func boardCenter(_ s: CGSize) -> CGPoint { CGPoint(x: s.width / 2, y: s.height * 0.42) }
    private func boardRadius(_ s: CGSize) -> CGFloat { s.width * 0.40 }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let c = boardCenter(size), R = boardRadius(size)
        let ink = GraphicsContext.Shading.color(Palette.ink)
        drawBoard(&ctx, c, R)

        for d in stuck { drawDart(&ctx, at: d.p, scale: 1) }

        // dardo en el aire: crece hacia el tablero
        if let f = flying {
            let u = min(1, now.timeIntervalSince(f.born) / flightTime)
            let e = 1 - pow(1 - u, 2)
            let p = CGPoint(x: f.from.x + (f.to.x - f.from.x) * e, y: f.from.y + (f.to.y - f.from.y) * e - sin(u * .pi) * size.height * 0.08)
            drawDart(&ctx, at: p, scale: 2.2 - 1.2 * u, flying: true)
        }

        // mira: tiembla con tu pulso, igual que el dardo se dispersa
        if (running || practicing), flying == nil {
            let a = settings.usesTouch ? touchAim : feed.aim
            let wobble = (1 - feed.steadiness) * R * 0.22
            let t = now.timeIntervalSinceReferenceDate
            let p = CGPoint(x: c.x + a.x * 1.05 * R + CGFloat(sin(t * 17)) * wobble, y: c.y - a.y * 1.05 * R + CGFloat(cos(t * 13)) * wobble)
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(Palette.rose), lineWidth: 1.4)
            var cross = Path()
            cross.move(to: CGPoint(x: p.x - 9, y: p.y)); cross.addLine(to: CGPoint(x: p.x - 3, y: p.y))
            cross.move(to: CGPoint(x: p.x + 3, y: p.y)); cross.addLine(to: CGPoint(x: p.x + 9, y: p.y))
            cross.move(to: CGPoint(x: p.x, y: p.y - 9)); cross.addLine(to: CGPoint(x: p.x, y: p.y - 3))
            cross.move(to: CGPoint(x: p.x, y: p.y + 3)); cross.addLine(to: CGPoint(x: p.x, y: p.y + 9))
            ctx.stroke(cross, with: .color(Palette.rose), lineWidth: 1.2)
        }

        // dardos que quedan en la ronda
        if running {
            for i in 0..<Darts.dartsPerTurn {
                let x = size.width / 2 + CGFloat(i - 1) * 16
                let has = i < game.dartsLeftInTurn
                var d = Path(); d.move(to: CGPoint(x: x, y: size.height * 0.845)); d.addLine(to: CGPoint(x: x, y: size.height * 0.885))
                ctx.stroke(d, with: has ? ink : .color(Palette.faint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        Effects.draw(particles, in: &ctx)
        Effects.draw(popups, in: &ctx, size: size, now: now)
    }

    private func drawBoard(_ ctx: inout GraphicsContext, _ c: CGPoint, _ R: CGFloat) {
        let ink = GraphicsContext.Shading.color(Palette.ink)
        func ring(_ f: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - R * f, y: c.y - R * f, width: 2 * R * f, height: 2 * R * f)) }
        // sectores alternos rellenos
        for i in 0..<20 where i % 2 == 0 {
            let a0 = Angle.degrees(Double(i) * 18 - 9 - 90), a1 = Angle.degrees(Double(i) * 18 + 9 - 90)
            var wedge = Path()
            wedge.addArc(center: c, radius: R, startAngle: a0, endAngle: a1, clockwise: false)
            wedge.addArc(center: c, radius: R * 0.094, startAngle: a1, endAngle: a0, clockwise: true)
            wedge.closeSubpath()
            ctx.fill(wedge, with: .color(Palette.ink.opacity(0.14)))
        }
        // borde de los sectores
        for i in 0..<20 {
            let a = (Double(i) * 18 - 9 - 90) * .pi / 180
            var l = Path()
            l.move(to: CGPoint(x: c.x + cos(a) * R * 0.094, y: c.y + sin(a) * R * 0.094))
            l.addLine(to: CGPoint(x: c.x + cos(a) * R, y: c.y + sin(a) * R))
            ctx.stroke(l, with: .color(Palette.ink.opacity(0.55)), lineWidth: 0.6)
        }
        for f in [1.0, 0.953, 0.629, 0.582] as [CGFloat] { ctx.stroke(ring(f), with: ink, lineWidth: f == 1.0 ? 1.4 : 0.8) }
        ctx.stroke(ring(0.094), with: ink, lineWidth: 1)
        ctx.fill(ring(0.037), with: .color(Palette.rose))
        ctx.stroke(ring(0.037), with: ink, lineWidth: 0.8)
        // numeros de los cuatro puntos cardinales
        for (i, n) in [(0, 20), (5, 6), (10, 3), (15, 11)] {
            let a = (Double(i) * 18 - 90) * .pi / 180
            ctx.draw(Text("\(n)").font(.system(size: 8, design: .serif)).foregroundColor(Palette.mid),
                     at: CGPoint(x: c.x + cos(a) * R * 1.12, y: c.y + sin(a) * R * 1.12))
        }
    }

    private func drawDart(_ ctx: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, flying: Bool = false) {
        // el dardo apunta hacia arriba-izquierda: punta en `p`, cuerpo hacia abajo-derecha
        let dx: CGFloat = 5 * s, dy: CGFloat = 12 * s
        var body = Path(); body.move(to: p); body.addLine(to: CGPoint(x: p.x + dx, y: p.y + dy))
        ctx.stroke(body, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        var wing = Path()
        wing.move(to: CGPoint(x: p.x + dx, y: p.y + dy))
        wing.addLine(to: CGPoint(x: p.x + dx + 4 * s, y: p.y + dy + 3 * s))
        wing.move(to: CGPoint(x: p.x + dx, y: p.y + dy))
        wing.addLine(to: CGPoint(x: p.x + dx - 1 * s, y: p.y + dy + 5 * s))
        ctx.stroke(wing, with: .color(Palette.rose), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
}
