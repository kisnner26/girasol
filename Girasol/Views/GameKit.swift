import SwiftUI
import GameCore

/// puente entre los sensores y un juego: alimenta el detector de gestos, guarda el historial de la puntería
/// (para saber hacia donde apuntabas justo antes de lanzar) y mide el temblor en vivo.
@MainActor
final class MotionFeed {
    var detector: SwingDetector
    private var tracker: AimTracker?
    private var history: [(t: Double, aim: Vec)] = []
    private var mags: [(t: Double, m: Double)] = []
    private(set) var aim = Vec(x: 0, y: 0)
    private(set) var magnitude = 0.0
    private(set) var running = false

    init(threshold: Double, cooldown: Double = 0.7, minDuration: Double = 0.03) {
        detector = SwingDetector(threshold: threshold, cooldown: cooldown, minDuration: minDuration)
    }

    /// 1 = mano quieta (ultimo medio segundo).
    var steadiness: Double { SwingDetector.steadiness(mags.map(\.m)) }

    /// hacia donde apuntabas en el instante `t`.
    func aim(at t: Double) -> Vec {
        history.min { abs($0.t - t) < abs($1.t - t) }?.aim ?? aim
    }

    /// como `aim(at:)`, ya convertido a coordenadas 0...1 del campo de tiro (y hacia arriba).
    func aimPoint(at t: Double) -> Vec {
        let a = MotionSettings.shared.usesTouch ? Vec(x: 0, y: 0) : aim(at: t)
        return Vec(x: 0.5 + a.x * 0.5, y: 0.5 + a.y * 0.5)
    }

    func start(threshold: Double? = nil, onSwing: @escaping (Swing) -> Void) {
        if let threshold { detector.threshold = threshold }
        detector.reset()
        history.removeAll(); mags.removeAll()
        tracker = MotionSettings.shared.mapping.map { AimTracker(mapping: $0) }
        running = true
        MotionService.shared.start(hz: 60) { [weak self] s in
            guard let self else { return }
            self.magnitude = s.accel.length
            if self.tracker != nil { self.aim = self.tracker!.update(s) }
            self.history.append((s.t, self.aim)); self.history.removeAll { s.t - $0.t > 1.0 }
            self.mags.append((s.t, self.magnitude)); self.mags.removeAll { s.t - $0.t > 0.5 }
            if let swing = self.detector.feed(s) { onSwing(swing) }
        }
    }

    func stop() {
        MotionService.shared.stop()
        running = false
    }
}

/// barrita que muestra el movimiento del reloj en vivo con la marca del umbral: sirve para ver si el gesto llega.
struct MotionMeter: View {
    let feed: MotionFeed
    let threshold: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            Canvas { ctx, size in
                let full = 3.0
                let w = size.width
                ctx.stroke(Path(CGRect(x: 0, y: size.height / 2 - 0.5, width: w, height: 1)), with: .color(Palette.faint), lineWidth: 1)
                let v = min(1, feed.magnitude / full) * w
                var bar = Path(); bar.move(to: CGPoint(x: 0, y: size.height / 2)); bar.addLine(to: CGPoint(x: v, y: size.height / 2))
                ctx.stroke(bar, with: .color(feed.magnitude >= threshold ? Palette.rose : Palette.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                let tx = min(1, threshold / full) * w
                var tick = Path(); tick.move(to: CGPoint(x: tx, y: 0)); tick.addLine(to: CGPoint(x: tx, y: size.height))
                ctx.stroke(tick, with: .color(Palette.mid), lineWidth: 1)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

struct Popup: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    let born: Date
    var big = false
}

struct Particle {
    var x: Double, y: Double, vx: Double, vy: Double, age = 0.0, life: Double, spin: Double
}

enum Effects {
    /// petalos de tinta que salen disparados al anotar.
    static func burst(at p: CGPoint, count: Int = 12, seed: Double = 0) -> [Particle] {
        (0..<count).map { i in
            let a = Double(i) / Double(count) * 2 * .pi + seed
            let sp = 60 + 50 * abs(sin(Double(i) * 1.7 + seed))
            return Particle(x: p.x, y: p.y, vx: cos(a) * sp, vy: sin(a) * sp - 30, life: 0.7 + 0.3 * abs(sin(Double(i))), spin: a)
        }
    }

    static func step(_ ps: inout [Particle], dt: Double) {
        for i in ps.indices {
            ps[i].age += dt
            ps[i].x += ps[i].vx * dt
            ps[i].y += ps[i].vy * dt
            ps[i].vy += 140 * dt
        }
        ps.removeAll { $0.age >= $0.life }
    }

    static func draw(_ ps: [Particle], in ctx: inout GraphicsContext) {
        for p in ps {
            let a = 1 - p.age / p.life
            var petal = Path(ellipseIn: CGRect(x: -2, y: -5, width: 4, height: 10))
            petal = petal.applying(CGAffineTransform(rotationAngle: p.spin + p.age * 6).concatenating(CGAffineTransform(translationX: p.x, y: p.y)))
            ctx.fill(petal, with: .color(Palette.ink.opacity(0.25 * a)))
            ctx.stroke(petal, with: .color(Palette.ink.opacity(0.9 * a)), lineWidth: 0.8)
        }
    }

    static func draw(_ popups: [Popup], in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        for p in popups {
            let age = now.timeIntervalSince(p.born)
            guard age < 1.1 else { continue }
            let a = age < 0.8 ? 1 : 1 - (age - 0.8) / 0.3
            let y = size.height * 0.5 - age * 22
            let text = Text(p.text).font(.system(size: p.big ? 22 : 16, design: .serif).italic()).foregroundColor(p.color.opacity(a))
            ctx.draw(text, at: CGPoint(x: size.width / 2, y: y))
        }
    }
}

/// gesto tactil convertido en un Swing, para cuando no hay sensores o se prefiere tocar.
func touchSwing(translation: CGSize, width: CGFloat) -> Swing {
    let len = (translation.width * translation.width + translation.height * translation.height).squareRoot() / width
    return Swing(time: 0, power: min(4, len * 4), duration: 0.2, direction: Vec3(x: translation.width / width, y: -translation.height / width, z: 0),
                 attitude: Attitude(roll: 0, pitch: 0, yaw: 0), steadiness: 1, gyroPeak: 0)
}

extension View {
    /// avanza el juego con un reloj propio en vez del de dibujo: al bajar la muñeca el reloj se atenua y deja de
    /// dibujar, pero la partida (y sus sensores) tiene que seguir corriendo.
    func gameLoop(_ tick: @escaping @MainActor (Date) -> Void) -> some View {
        task {
            while !Task.isCancelled {
                tick(Date())
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}
