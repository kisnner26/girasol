import SwiftUI
import GameCore

struct AirBasketballView: View {
    @State private var game = AirBasketball(seed: UInt64(Date().timeIntervalSince1970))
    @State private var running = false
    @State private var finished = false
    @State private var practicing = false
    @State private var practiceCount = 0
    @State private var feed = MotionFeed(threshold: MotionSettings.shared.threshold)
    @State private var clock = FrameClock()
    @State private var popups: [Popup] = []
    @State private var particles: [Particle] = []
    @State private var lastPhase = AirBasketball.Phase.aiming
    @State private var lastSize = CGSize(width: 200, height: 240)
    @AppStorage("girasol.best.airbasket") private var best = 0
    private let settings = MotionSettings.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
                    Canvas { ctx, size in draw(&ctx, size, tl.date) }
                }
                GameHUD(left: "\(game.score) pts", right: "\(Int(game.timeLeft.rounded(.up))) s")
                if running && game.streak >= 2 {
                    Caption("racha \(game.streak)", color: Palette.rose).frame(maxHeight: .infinity, alignment: .top).padding(.top, 40)
                }
                if settings.showMeter && !settings.usesTouch && (running || practicing) {
                    MotionMeter(feed: feed, threshold: settings.threshold)
                        .padding(.horizontal, 30).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 4)
                }
                overlay
            }
            .gameLoop { advance($0, geo.size) }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 12).onEnded { v in
                guard settings.usesTouch else { return }
                handle(touchSwing(translation: v.translation, width: geo.size.width))
            })
        }
        .paperBackground()
        .keepAwake()
        .navigationBarBackButtonHidden(running)
        .onDisappear { feed.stop() }
    }

    // MARK: pantalla de inicio / fin

    @ViewBuilder private var overlay: some View {
        if practicing {
            GameOverlay(title: "calentamiento", subtitle: "lanza con la muñeca como un tiro normal: \(practiceCount) de \(PowerCalibration.needed)",
                        button: "") { }
                .allowsHitTesting(false)
        } else if !running {
            GameOverlay(title: finished ? "\(game.score) puntos" : "baloncesto de muñeca",
                        subtitle: finished ? "mejor \(best) · \(game.made) de \(game.shots) · racha \(game.bestStreak)"
                                           : (settings.usesTouch ? "desliza hacia arriba: la fuerza es el largo."
                                                                 : "lanza con un gesto de muñeca. la fuerza decide la distancia; inclina para apuntar."),
                        button: finished ? "otra vez" : "empezar") { begin() }
        }
    }

    // MARK: flujo

    private func begin() {
        clock.reset()
        finished = false
        if !settings.usesTouch && !settings.basketPower.isReady {
            practicing = true
            practiceCount = 0
            startMotion()
            return
        }
        game = AirBasketball(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        popups = []; particles = []
        lastPhase = .aiming
        running = true
        Haptics.play(.start)
        if !settings.usesTouch { startMotion() }
    }

    private func startMotion() {
        feed.start(threshold: settings.threshold) { sw in handle(sw) }
    }

    private func handle(_ sw: Swing) {
        Sfx.shared.play(.whoosh)
        Haptics.play(.directionUp)
        if practicing {
            settings.basketPower.add(sw.power)
            practiceCount += 1
            if settings.basketPower.isReady {
                practicing = false
                Haptics.play(.success)
                begin()
            }
            return
        }
        guard running else { return }
        let power = settings.usesTouch ? sw.power / 2.0 : settings.basketPower.normalized(sw.power)
        let aim = settings.usesTouch ? max(-1, min(1, sw.direction.x * 2.2)) : feed.aim(at: sw.time - 0.18).x
        game.shoot(power: power, aim: aim)
    }

    private func advance(_ now: Date, _ size: CGSize) {
        lastSize = size
        guard running else { clock.reset(); return }
        let dt = clock.dt(now)
        game.step(dt: dt)
        Effects.step(&particles, dt: dt)
        if game.phase != lastPhase {
            if game.phase == .result { resolved(size) }
            lastPhase = game.phase
        }
        if game.isOver {
            running = false
            finished = true
            best = max(best, game.score)
            feed.stop()
            Haptics.play(.notification)
        }
    }

    private func resolved(_ size: CGSize) {
        guard let o = game.outcome else { return }
        let hoop = CGPoint(x: size.width / 2, y: size.height * 0.32)
        switch o {
        case .swish:
            Sfx.shared.play(.swish); Sfx.shared.play(.ding); Haptics.play(.success)
            popups.append(Popup(text: "swish +\(game.lastPoints)", color: Palette.ink, born: Date(), big: true))
            particles += Effects.burst(at: hoop, count: 14)
        case .basket:
            Sfx.shared.play(.swish); Sfx.shared.play(.ding); Haptics.play(.success)
            popups.append(Popup(text: "canasta +\(game.lastPoints)", color: Palette.moss, born: Date()))
            particles += Effects.burst(at: hoop, count: 9)
        case .rimIn:
            Sfx.shared.play(.bounce); Sfx.shared.play(.swish); Haptics.play(.success)
            popups.append(Popup(text: "de rebote +\(game.lastPoints)", color: Palette.olive, born: Date()))
            particles += Effects.burst(at: hoop, count: 8)
        case .rimOut:
            Sfx.shared.play(.bounce); Haptics.play(.retry)
            popups.append(Popup(text: "¡el aro!", color: Palette.rose, born: Date()))
        case .short, .long, .left, .right:
            Sfx.shared.play(.buzz); Haptics.play(.failure)
            let text = ["short": "corto", "long": "largo", "left": "muy a la izquierda", "right": "muy a la derecha"]["\(o)"] ?? "fallo"
            popups.append(Popup(text: text, color: Palette.rose, born: Date()))
        }
        popups.removeAll { Date().timeIntervalSince($0.born) > 1.2 }
    }

    // MARK: dibujo

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let w = size.width, h = size.height
        let ink = GraphicsContext.Shading.color(Palette.ink)
        let faint = GraphicsContext.Shading.color(Palette.faint)
        let scale = CGFloat(min(1.3, max(0.72, pow(1 / game.distance, 0.8))))
        let hoop = CGPoint(x: w / 2, y: h * 0.32)

        // suelo en perspectiva
        for i in 0...8 {
            var l = Path(); l.move(to: CGPoint(x: w / 2, y: h * 0.44)); l.addLine(to: CGPoint(x: w * Double(i) / 8, y: h))
            ctx.stroke(l, with: faint, lineWidth: 0.6)
        }
        for k in 1...4 {
            let y = h * (0.44 + 0.56 * pow(Double(k) / 4, 1.8))
            var l = Path(); l.move(to: CGPoint(x: 0, y: y)); l.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(l, with: faint, lineWidth: 0.6)
        }

        // tablero
        let bw = w * 0.34 * scale, bh = h * 0.20 * scale
        let board = CGRect(x: hoop.x - bw / 2, y: hoop.y - bh * 0.85, width: bw, height: bh)
        ctx.fill(Path(board), with: .color(Palette.paper))
        ctx.stroke(Path(board), with: ink, lineWidth: 1.3)
        ctx.stroke(Path(CGRect(x: hoop.x - bw * 0.18, y: hoop.y - bh * 0.38, width: bw * 0.36, height: bh * 0.3)), with: .color(Palette.mid), lineWidth: 1)

        let rimW = w * 0.22 * scale, rimH = h * 0.045 * scale
        let ball = ballState(size, now)
        // los tiros que entran se dibujan detras de la red (parecen caer por dentro)
        let scored = game.phase != .aiming && [.swish, .basket, .rimIn].contains(game.outcome)
        if scored { drawBall(&ctx, ball) }
        drawNet(&ctx, hoop, rimW, rimH, scale)
        if !scored { drawBall(&ctx, ball) }
        var rim = Path(ellipseIn: CGRect(x: hoop.x - rimW / 2, y: hoop.y - rimH / 2, width: rimW, height: rimH))
        ctx.stroke(rim, with: .color(Palette.rose), lineWidth: 2)
        rim = Path()

        // medidor de fuerza objetivo
        drawPowerGauge(&ctx, size)
        Effects.draw(particles, in: &ctx)
        Effects.draw(popups, in: &ctx, size: size, now: now)
    }

    private func drawNet(_ ctx: inout GraphicsContext, _ hoop: CGPoint, _ rimW: CGFloat, _ rimH: CGFloat, _ scale: CGFloat) {
        let sway = game.phase == .result && [.swish, .basket, .rimIn].contains(game.outcome) ? sin(game.phaseTime * 26) * 3 * (1 - game.phaseTime / AirBasketball.resultTime) : 0
        let bottomY = hoop.y + h(scale) * 0.85
        for i in 0...6 {
            let f = CGFloat(i) / 6
            var l = Path()
            l.move(to: CGPoint(x: hoop.x - rimW / 2 + rimW * f, y: hoop.y))
            l.addLine(to: CGPoint(x: hoop.x - rimW * 0.28 + rimW * 0.56 * f + sway, y: bottomY))
            ctx.stroke(l, with: .color(Palette.mid.opacity(0.8)), lineWidth: 0.8)
        }
        for k in 1...2 {
            let f = CGFloat(k) / 3
            let y = hoop.y + (bottomY - hoop.y) * f
            let half = rimW / 2 * (1 - 0.44 * f)
            var l = Path(); l.move(to: CGPoint(x: hoop.x - half + sway * f, y: y)); l.addLine(to: CGPoint(x: hoop.x + half + sway * f, y: y))
            ctx.stroke(l, with: .color(Palette.mid.opacity(0.7)), lineWidth: 0.7)
        }
    }

    private func h(_ scale: CGFloat) -> CGFloat { lastSize.height * 0.11 * scale }

    private struct BallState { var pos: CGPoint; var radius: CGFloat; var alpha: Double; var shadowY: CGFloat }

    private func ballState(_ size: CGSize, _ now: Date) -> BallState {
        let w = size.width, h = size.height
        let start = CGPoint(x: w / 2, y: h * 0.86)
        let hoopY = h * 0.32
        let scale = CGFloat(min(1.3, max(0.72, pow(1 / game.distance, 0.8))))
        let r0 = w * 0.105, r1 = w * 0.045 * scale
        if game.phase == .aiming {
            let bob = CGFloat(sin(now.timeIntervalSinceReferenceDate * 3)) * 2
            return BallState(pos: CGPoint(x: start.x, y: start.y + bob), radius: r0, alpha: 1, shadowY: h * 0.95)
        }
        let a = game.lastAim
        let o = game.outcome ?? .swish
        var end = CGPoint(x: w / 2, y: hoopY + 4)
        switch o {
        case .swish: break
        case .basket: end.x += CGFloat(a) * w * 0.05
        case .rimIn: end.x += CGFloat(a) * w * 0.10
        case .rimOut: end.x += (a >= 0 ? 1 : -1) * w * 0.13 * scale; end.y -= h * 0.02
        case .short: end.x += CGFloat(a) * w * 0.08; end.y += h * 0.17
        case .long: end.x += CGFloat(a) * w * 0.08; end.y -= h * 0.20
        case .left: end.x -= w * 0.30
        case .right: end.x += w * 0.30
        }
        let u = CGFloat(game.flightProgress)
        let arc = h * (0.20 + 0.10 * CGFloat(min(1.6, game.lastPower)))
        var pos = CGPoint(x: start.x + (end.x - start.x) * u, y: start.y + (end.y - start.y) * u - 4 * u * (1 - u) * arc)
        var radius = r0 + (r1 - r0) * pow(u, 0.75)
        var alpha = 1.0
        if game.phase == .result {
            let t = CGFloat(game.phaseTime / AirBasketball.resultTime)
            pos = end
            radius = r1
            switch o {
            case .swish, .basket, .rimIn: pos.y += t * h * 0.22 * scale; alpha = Double(1 - t * 0.8)
            case .rimOut: pos.x += (a >= 0 ? 1 : -1) * t * w * 0.30; pos.y += t * t * h * 0.5 - t * h * 0.06; alpha = Double(1 - t)
            default: alpha = Double(max(0, 1 - t * 1.6))
            }
        }
        return BallState(pos: pos, radius: radius, alpha: alpha, shadowY: h * 0.95)
    }

    private func drawBall(_ ctx: inout GraphicsContext, _ b: BallState) {
        guard b.alpha > 0.01 else { return }
        let r = b.radius
        // sombra
        if b.pos.y < b.shadowY - 8 {
            let s = r * 1.5
            ctx.fill(Path(ellipseIn: CGRect(x: b.pos.x - s, y: b.shadowY - s * 0.22, width: 2 * s, height: s * 0.44)), with: .color(Palette.ink.opacity(0.10 * b.alpha)))
        }
        let circle = Path(ellipseIn: CGRect(x: b.pos.x - r, y: b.pos.y - r, width: 2 * r, height: 2 * r))
        ctx.fill(circle, with: .color(Palette.paperDark.opacity(b.alpha)))
        ctx.stroke(circle, with: .color(Palette.ink.opacity(b.alpha)), lineWidth: 1.3)
        var seams = Path()
        seams.move(to: CGPoint(x: b.pos.x - r, y: b.pos.y)); seams.addLine(to: CGPoint(x: b.pos.x + r, y: b.pos.y))
        seams.move(to: CGPoint(x: b.pos.x, y: b.pos.y - r)); seams.addLine(to: CGPoint(x: b.pos.x, y: b.pos.y + r))
        seams.addArc(center: CGPoint(x: b.pos.x - r * 1.05, y: b.pos.y), radius: r * 0.95, startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
        seams.move(to: CGPoint(x: b.pos.x + r * 0.05, y: b.pos.y))
        seams.addArc(center: CGPoint(x: b.pos.x + r * 1.05, y: b.pos.y), radius: r * 0.95, startAngle: .degrees(130), endAngle: .degrees(230), clockwise: false)
        ctx.stroke(seams, with: .color(Palette.ink.opacity(0.7 * b.alpha)), lineWidth: 0.8)
    }

    /// barra de 0.5 a 1.5 de fuerza: la zona oscura es la del swish para el tiro actual; el triangulo, tu ultimo tiro.
    private func drawPowerGauge(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard running else { return }
        let w = size.width * 0.62, x0 = (size.width - w) / 2, y = size.height * 0.955
        func px(_ p: Double) -> CGFloat { x0 + w * CGFloat((min(1.5, max(0.5, p)) - 0.5) / 1.0) }
        let d = game.distance
        ctx.stroke(Path(CGRect(x: x0, y: y - 0.5, width: w, height: 1)), with: .color(Palette.faint), lineWidth: 1)
        var basket = Path(); basket.move(to: CGPoint(x: px(d * 0.76), y: y)); basket.addLine(to: CGPoint(x: px(d * 1.24), y: y))
        ctx.stroke(basket, with: .color(Palette.moss.opacity(0.5)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        var swish = Path(); swish.move(to: CGPoint(x: px(d * 0.88), y: y)); swish.addLine(to: CGPoint(x: px(d * 1.12), y: y))
        ctx.stroke(swish, with: .color(Palette.moss), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        if game.shots > 0 {
            let m = px(game.lastPower)
            var tri = Path(); tri.move(to: CGPoint(x: m, y: y - 3)); tri.addLine(to: CGPoint(x: m - 3, y: y - 9)); tri.addLine(to: CGPoint(x: m + 3, y: y - 9)); tri.closeSubpath()
            ctx.fill(tri, with: .color(Palette.ink))
        }
    }
}
