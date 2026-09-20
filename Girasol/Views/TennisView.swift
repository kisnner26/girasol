import SwiftUI
import GameCore

/// tenis de reflejos: la pelota viene hacia ti y le pegas con un golpe de muñeca justo cuando llega al anillo.
struct TennisView: View {
    @State private var game = Tennis(seed: UInt64(Date().timeIntervalSince1970))
    @State private var running = false
    @State private var finished = false
    @State private var feed = MotionFeed(threshold: MotionSettings.shared.threshold, cooldown: 0.25)
    @State private var clock = FrameClock()
    @State private var popups: [Popup] = []
    @State private var particles: [Particle] = []
    @State private var swingAt: Date?
    @State private var lastPhase = Tennis.Phase.waiting
    @AppStorage("girasol.best.tennis") private var best = 0
    private let settings = MotionSettings.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
                    Canvas { ctx, size in draw(&ctx, size, tl.date) }
                }
                GameHUD(left: "\(game.score) pts", right: lives)
                if running && game.rally >= 2 {
                    Caption("\(game.rally) seguidas", color: Palette.rose).frame(maxHeight: .infinity, alignment: .top).padding(.top, 40)
                }
                if settings.showMeter && !settings.usesTouch && running {
                    MotionMeter(feed: feed, threshold: settings.threshold)
                        .padding(.horizontal, 30).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 3)
                }
                if !running {
                    GameOverlay(title: finished ? "\(game.score) puntos" : "tenis",
                                subtitle: finished ? "mejor \(best) · racha máxima \(game.bestRally)"
                                                   : (settings.usesTouch ? "toca cuando la pelota llegue al anillo."
                                                                         : "golpea con la muñeca justo cuando la pelota llega al anillo. tres fallos y termina."),
                                button: finished ? "otra vez" : "empezar") { begin() }
                }
            }
            .gameLoop { advance($0) }
            .contentShape(Rectangle())
            .onTapGesture { if settings.usesTouch && running { hit() } }
        }
        .paperBackground()
        .keepAwake()
        .navigationBarBackButtonHidden(running)
        .onDisappear { feed.stop() }
    }

    private var lives: String { String(repeating: "♥", count: max(0, game.livesLeft)) }

    private func begin() {
        game = Tennis(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        popups = []; particles = []
        clock.reset()
        lastPhase = .waiting
        finished = false
        running = true
        Haptics.play(.start)
        if !settings.usesTouch { feed.start(threshold: settings.threshold) { _ in hit() } }
    }

    private func hit() {
        guard running else { return }
        swingAt = Date()
        Sfx.shared.play(.whoosh)
        guard let r = game.swing() else { return }
        switch r {
        case .perfect:
            Sfx.shared.play(.pok); Sfx.shared.play(.ding); Haptics.play(.success)
            popups.append(Popup(text: "perfecto +2", color: Palette.ink, born: Date(), big: true))
            particles += Effects.burst(at: CGPoint(x: 100, y: 190), count: 12)
        case .good:
            Sfx.shared.play(.pok); Haptics.play(.click)
            popups.append(Popup(text: "bien +1", color: Palette.moss, born: Date()))
        case .early:
            Sfx.shared.play(.buzz); Haptics.play(.failure)
            popups.append(Popup(text: "muy pronto", color: Palette.rose, born: Date()))
        case .late:
            Sfx.shared.play(.buzz); Haptics.play(.failure)
            popups.append(Popup(text: "tarde", color: Palette.rose, born: Date()))
        case .miss:
            break
        }
    }

    private func advance(_ now: Date) {
        guard running else { clock.reset(); return }
        let dt = clock.dt(now)
        game.step(dt: dt)
        Effects.step(&particles, dt: dt)
        if game.phase != lastPhase {
            // la pelota paso sin que la golpearas
            if lastPhase == .incoming && game.phase == .result && game.lastReturn == .miss {
                Sfx.shared.play(.buzz); Haptics.play(.failure)
                popups.append(Popup(text: "fallaste", color: Palette.rose, born: Date()))
            }
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

    // MARK: dibujo

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let w = size.width, h = size.height
        let vp = CGPoint(x: w / 2, y: h * 0.30)

        // cancha en perspectiva
        var court = Path()
        court.move(to: CGPoint(x: w * 0.36, y: vp.y)); court.addLine(to: CGPoint(x: w * 0.64, y: vp.y))
        court.addLine(to: CGPoint(x: w * 0.98, y: h * 0.86)); court.addLine(to: CGPoint(x: w * 0.02, y: h * 0.86)); court.closeSubpath()
        ctx.stroke(court, with: .color(Palette.mid), lineWidth: 1)
        var mid = Path(); mid.move(to: vp); mid.addLine(to: CGPoint(x: w / 2, y: h * 0.86))
        ctx.stroke(mid, with: .color(Palette.faint), lineWidth: 0.6)
        for f in [0.3, 0.6] {
            let y = vp.y + (h * 0.86 - vp.y) * f
            let half = w * (0.14 + 0.34 * f)
            var l = Path(); l.move(to: CGPoint(x: w / 2 - half, y: y)); l.addLine(to: CGPoint(x: w / 2 + half, y: y))
            ctx.stroke(l, with: .color(Palette.faint), lineWidth: 0.5)
        }

        // anillo de golpeo: cerca de ti
        let target = CGPoint(x: w / 2, y: h * 0.74)
        let ringR: CGFloat = 20
        let near = game.phase == .incoming && abs(game.timeToHit) < Tennis.goodWindow
        ctx.stroke(Path(ellipseIn: CGRect(x: target.x - ringR, y: target.y - ringR, width: ringR * 2, height: ringR * 2)),
                   with: .color(near ? Palette.rose : Palette.ink), lineWidth: near ? 2.2 : 1.3)

        // pelota: crece y baja hacia el anillo
        if game.phase == .incoming || game.phase == .result {
            let p = game.ballProgress
            let e = p * p                                   // acelera al acercarse
            let lane = game.lane * 0.22 * w * (1 - e * 0.6)
            let pos = CGPoint(x: vp.x + lane * e + (target.x - vp.x) * 0 , y: vp.y + (target.y - vp.y) * e)
            let r = 3 + 11 * e
            if game.phase == .result, let ret = game.lastReturn, ret == .perfect || ret == .good {
                // devuelta: sube hacia el fondo
                let k = min(1, game.clock / 0.7)
                let back = CGPoint(x: target.x, y: target.y - (target.y - vp.y) * k)
                let rr = 14 - 11 * k
                drawBall(&ctx, back, rr)
            } else if !(game.phase == .result && (game.lastReturn == .early || game.lastReturn == .late)) {
                drawBall(&ctx, pos, r)
            } else {
                drawBall(&ctx, CGPoint(x: pos.x + (pos.x - w / 2) * game.clock * 3, y: pos.y + game.clock * 30), r)
            }
        }

        // raqueta
        let sw = swingAt.map { now.timeIntervalSince($0) } ?? 1
        if sw < 0.22 {
            let k = sw / 0.22
            let ang = -0.9 + 1.8 * k
            var r = Path(ellipseIn: CGRect(x: -9, y: -20, width: 18, height: 24))
            r.move(to: CGPoint(x: 0, y: 4)); r.addLine(to: CGPoint(x: 0, y: 16))
            let t = CGAffineTransform(translationX: target.x, y: h * 0.90).rotated(by: ang)
            ctx.stroke(r.applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: target.x, y: h * 0.90))),
                       with: .color(Palette.ink), lineWidth: 1.6)
            _ = t
        }
        Effects.draw(particles, in: &ctx)
        Effects.draw(popups, in: &ctx, size: size, now: now)
    }

    private func drawBall(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Palette.olive.opacity(0.85)))
        ctx.stroke(Path(ellipseIn: rect), with: .color(Palette.ink), lineWidth: 1)
        var seam = Path()
        seam.addArc(center: CGPoint(x: c.x - r * 1.1, y: c.y), radius: r * 0.9, startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
        ctx.stroke(seam, with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.7)
    }
}
