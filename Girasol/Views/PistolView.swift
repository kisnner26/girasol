import SwiftUI
import GameCore

/// campo de tiro: la mira sigue tu muñeca y disparas con el retroceso del gesto. recarga girando la corona.
struct PistolView: View {
    @State private var game = Shooter(seed: UInt64(Date().timeIntervalSince1970))
    @State private var running = false
    @State private var finished = false
    @State private var feed = MotionFeed(threshold: MotionSettings.shared.threshold * 1.15, cooldown: 0.22, minDuration: 0.02)
    @State private var clock = FrameClock()
    @State private var crown = 0.0
    @State private var shots: [(p: Vec, born: Date, hit: Bool)] = []
    @State private var flash: Date?
    @State private var touchAim = Vec(x: 0.5, y: 0.5)
    @State private var popups: [Popup] = []
    @State private var particles: [Particle] = []
    @AppStorage("girasol.best.pistol") private var best = 0
    @AppStorage("girasol.pistol.laser") private var laser = false
    private let settings = MotionSettings.shared

    /// mira en coordenadas del tablero (0...1, y hacia arriba).
    private var crosshair: Vec {
        settings.usesTouch ? touchAim : Vec(x: 0.5 + feed.aim.x * 0.5, y: 0.5 + feed.aim.y * 0.5)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
                    Canvas { ctx, size in draw(&ctx, size, tl.date) }
                        .onChange(of: tl.date) { _, now in advance(now, geo.size) }
                }
                GameHUD(left: "\(game.score) pts", right: "\(Int(game.timeLeft.rounded(.up))) s")
                ammo
                if settings.showMeter && !settings.usesTouch && running {
                    MotionMeter(feed: feed, threshold: feed.detector.threshold)
                        .padding(.horizontal, 30).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 2)
                }
                overlay
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                guard settings.usesTouch, running else { return }
                touchAim = Vec(x: v.location.x / geo.size.width, y: 1 - v.location.y / geo.size.height)
                fire(at: touchAim)
            })
        }
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: 1, by: nil, sensitivity: .high, isContinuous: true, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { old, new in
            guard running else { return }
            var d = new - old
            if abs(d) > 0.5 { d += d > 0 ? -1 : 1 }
            let before = game.ammo
            game.crown(turns: d)
            if game.ammo > before { Haptics.play(.success); Sfx.shared.play(.reload) }
        }
        .paperBackground()
        .navigationBarBackButtonHidden(running)
        .onDisappear { feed.stop() }
    }

    // MARK: pantallas

    private var ammo: some View {
        VStack {
            Spacer()
            if game.needsReload && running {
                Text("gira la corona").font(.serif(12, italic: true)).foregroundStyle(Palette.rose)
            }
            HStack(spacing: 4) {
                ForEach(0..<Shooter.magazine, id: \.self) { i in
                    Capsule().fill(i < game.ammo ? Palette.ink : Color.clear)
                        .overlay(Capsule().stroke(Palette.ink, lineWidth: 0.8)).frame(width: 5, height: 11)
                }
            }
            .padding(.bottom, running && settings.showMeter && !settings.usesTouch ? 12 : 8)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var overlay: some View {
        if !settings.usesTouch && settings.mapping == nil && !running {
            VStack(spacing: 8) {
                Text("pistola").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Text("primero calibra tu puntería: son 10 segundos.").font(.serif(11, italic: true)).foregroundStyle(Palette.mid)
                    .multilineTextAlignment(.center)
                NavigationLink(value: Route.calibrate) { Caption("calibrar", color: Palette.ink) }.buttonStyle(InkButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper.opacity(0.95))
        } else if !running {
            VStack(spacing: 6) {
                Text(finished ? "\(game.score) puntos" : (laser ? "láser" : "pistola")).font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Text(finished ? "mejor \(best) · \(game.hits) de \(game.shots) tiros"
                              : (settings.usesTouch ? "toca los blancos. no le dispares al corazón."
                                                    : "apunta con la muñeca; dispara con un tirón corto hacia arriba. no le dispares al corazón."))
                    .font(.serif(11, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
                Button(laser ? "modo: láser ✦" : "modo: pistola") { laser.toggle(); Haptics.play(.click) }.buttonStyle(QuietButtonStyle())
                Button(finished ? "otra vez" : "empezar") { begin() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.paper.opacity(0.94))
        }
    }

    // MARK: flujo

    private func begin() {
        game = Shooter(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        shots = []; popups = []; particles = []
        clock.reset()
        finished = false
        running = true
        Haptics.play(.start)
        if !settings.usesTouch {
            feed.start(threshold: settings.threshold * 1.15) { sw in
                guard running else { return }
                fire(at: feed.aimPoint(at: sw.time - 0.12))
            }
        }
    }

    private func fire(at: Vec) {
        flash = Date()
        switch game.shoot(at: at) {
        case .hit(let kind):
            Sfx.shared.play(laser ? .pew : .bang)
            if kind == .friend { Haptics.play(.failure); Sfx.shared.play(.buzz); popups.append(Popup(text: "−2", color: Palette.rose, born: Date(), big: true)) }
            else {
                Haptics.play(.success); Sfx.shared.play(.hit)
                popups.append(Popup(text: kind == .quick ? "+3" : "+1", color: Palette.ink, born: Date(), big: kind == .quick))
                particles += Effects.burst(at: CGPoint(x: at.x * 200, y: (1 - at.y) * 240), count: kind == .quick ? 10 : 6)
            }
            shots.append((at, Date(), true))
        case .miss:
            Sfx.shared.play(laser ? .pew : .bang); Haptics.play(.click)
            shots.append((at, Date(), false))
        case .empty:
            Sfx.shared.play(.empty); Haptics.play(.retry)
        }
        popups.removeAll { Date().timeIntervalSince($0.born) > 1.2 }
    }

    private func advance(_ now: Date, _ size: CGSize) {
        guard running else { clock.reset(); return }
        let dt = clock.dt(now)
        game.step(dt: dt)
        Effects.step(&particles, dt: dt)
        shots.removeAll { now.timeIntervalSince($0.born) > 2 }
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
        // retroceso: la escena da un tiron hacia abajo un instante
        let kick = flash.map { max(0, 1 - now.timeIntervalSince($0) / 0.12) * 5 } ?? 0
        ctx.translateBy(x: 0, y: CGFloat(kick))

        // suelo y lineas de fuga del campo
        for i in 0...6 {
            var l = Path(); l.move(to: CGPoint(x: w / 2, y: h * 0.30)); l.addLine(to: CGPoint(x: w * Double(i) / 6, y: h))
            ctx.stroke(l, with: .color(Palette.faint), lineWidth: 0.5)
        }
        var horizon = Path(); horizon.move(to: CGPoint(x: 0, y: h * 0.30)); horizon.addLine(to: CGPoint(x: w, y: h * 0.30))
        ctx.stroke(horizon, with: .color(Palette.mid), lineWidth: 0.8)

        for t in game.targets { drawTarget(&ctx, t, size) }

        // impactos
        for s in shots {
            let a = 1 - now.timeIntervalSince(s.born) / 2
            let p = CGPoint(x: s.p.x * w, y: (1 - s.p.y) * h)
            var x = Path()
            x.move(to: CGPoint(x: p.x - 3, y: p.y - 3)); x.addLine(to: CGPoint(x: p.x + 3, y: p.y + 3))
            x.move(to: CGPoint(x: p.x + 3, y: p.y - 3)); x.addLine(to: CGPoint(x: p.x - 3, y: p.y + 3))
            ctx.stroke(x, with: .color((s.hit ? Palette.moss : Palette.mid).opacity(a)), lineWidth: 1.2)
        }

        // mira
        if running {
            let c = crosshair
            let p = CGPoint(x: c.x * w, y: (1 - c.y) * h)
            let col = Palette.rose
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(col), lineWidth: 1.3)
            var cross = Path()
            for (a, b) in [((-14.0, 0.0), (-5.0, 0.0)), ((5.0, 0.0), (14.0, 0.0)), ((0.0, -14.0), (0.0, -5.0)), ((0.0, 5.0), (0.0, 14.0))] {
                cross.move(to: CGPoint(x: p.x + a.0, y: p.y + a.1)); cross.addLine(to: CGPoint(x: p.x + b.0, y: p.y + b.1))
            }
            ctx.stroke(cross, with: .color(col), lineWidth: 1.3)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.2, y: p.y - 1.2, width: 2.4, height: 2.4)), with: .color(col))
            // fogonazo
            if let f = flash, now.timeIntervalSince(f) < 0.12 {
                let k = CGFloat(now.timeIntervalSince(f) / 0.12)
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 8 - 14 * k, y: p.y - 8 - 14 * k, width: 16 + 28 * k, height: 16 + 28 * k)),
                           with: .color(Palette.ink.opacity(1 - Double(k))), lineWidth: 2)
            }
        }
        Effects.draw(particles, in: &ctx)
        Effects.draw(popups, in: &ctx, size: size, now: now)
    }

    private func drawTarget(_ ctx: inout GraphicsContext, _ t: Shooter.Target, _ size: CGSize) {
        let w = size.width, h = size.height
        let c = CGPoint(x: t.center.x * w, y: (1 - t.center.y) * h)
        let r = t.radius * w
        let life = t.remaining / t.lifetime
        func ring(_ f: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r * f, y: c.y - r * f, width: 2 * r * f, height: 2 * r * f)) }
        switch t.kind {
        case .normal:
            ctx.stroke(ring(1), with: .color(Palette.ink), lineWidth: 1.4)
            ctx.stroke(ring(0.62), with: .color(Palette.ink), lineWidth: 1.1)
            ctx.fill(ring(0.24), with: .color(Palette.ink))
        case .quick:
            ctx.stroke(ring(1), with: .color(Palette.olive), lineWidth: 1.6)
            ctx.fill(ring(0.42), with: .color(Palette.olive))
        case .friend:
            ctx.fill(ring(1), with: .color(Palette.paperDark))
            ctx.stroke(ring(1), with: .color(Palette.rose), lineWidth: 1.4)
            ctx.draw(Text("♥").font(.system(size: r * 1.1)).foregroundColor(Palette.rose), at: c)
        }
        var bar = Path()
        bar.move(to: CGPoint(x: c.x - r * 0.6, y: c.y + r + 3)); bar.addLine(to: CGPoint(x: c.x - r * 0.6 + r * 1.2 * life, y: c.y + r + 3))
        ctx.stroke(bar, with: .color(Palette.faint), lineWidth: 1)
    }
}
