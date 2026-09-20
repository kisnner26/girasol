import SwiftUI
import HealthCore

/// flor que se abre al inhalar y se cierra al exhalar.
struct BreathFlower: View {
    let scale: Double   // 0...1
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    Petal(index: i, count: 10, length: 0.55 + 0.45 * scale)
                        .fill(Palette.ink.opacity(0.06 + 0.16 * scale))
                    Petal(index: i, count: 10, length: 0.55 + 0.45 * scale)
                        .stroke(Palette.ink.opacity(0.85), lineWidth: 0.9)
                }
                Circle().stroke(Palette.ink, lineWidth: 1).frame(width: side * 0.32, height: side * 0.32)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct BreatheView: View {
    @Environment(HealthModel.self) private var health
    @Environment(BreathingRunner.self) private var runner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch runner.state {
        case .idle: setup
        case .running: SessionView()
        case .finished: FinishedView()
        }
    }

    private var setup: some View {
        @Bindable var store = health.profiles
        return ScrollView {
            VStack(spacing: 10) {
                Caption("respirar")
                BreathFlower(scale: 0.5).frame(width: 70, height: 70)
                Text("un minuto para ti").font(.serif(15, italic: true)).foregroundStyle(Palette.ink)
                ChoiceRow(title: "ritmo",
                          options: BreathingPattern.all.map { ($0.id, "\($0.title) · \($0.detail)") },
                          selection: $store.profile.breathingPattern)
                ChoiceRow(title: "duración",
                          options: [1, 2, 3, 5].map { ($0, $0 == 1 ? loc("1 minuto") : loc("\($0) minutos")) },
                          selection: $store.profile.breathingMinutes)
                Button("empezar") {
                    let p = health.profile
                    runner.begin(pattern: .pattern(id: p.breathingPattern), minutes: p.breathingMinutes)
                }
                .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                Text("vibra al ritmo: sube al inhalar, baja al exhalar. funciona con la muñeca baja.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
    }
}

private struct SessionView: View {
    @Environment(BreathingRunner.self) private var runner

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            let t = runner.elapsed
            let m = runner.session?.moment(at: t)
            VStack(spacing: 4) {
                BreathFlower(scale: m?.scale ?? 0)
                    .frame(width: 130, height: 130)
                Text(m?.phase.label ?? "").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Caption(verbatim: remainingText(m?.remaining ?? 0))
                Button("terminar") { runner.finish(completed: false) }.buttonStyle(QuietButtonStyle())
            }
        }
        .paperBackground()
        .navigationBarBackButtonHidden(true)
    }

    private func remainingText(_ s: Double) -> String {
        let n = Int(s.rounded(.up))
        return n >= 60 ? "\(n / 60):\(String(format: "%02d", n % 60))" : "\(n) s"
    }
}

private struct FinishedView: View {
    @Environment(BreathingRunner.self) private var runner
    @Environment(HealthModel.self) private var health
    @State private var saved = false

    var body: some View {
        let secs = Int(runner.elapsed.rounded())
        VStack(spacing: 8) {
            Sprig().frame(width: 40, height: 56)
            Text(runner.completed ? "bien hecho" : "sesión corta").font(.serif(18, italic: true)).foregroundStyle(Palette.ink)
            Caption("\(secs) s de calma")
            Button("listo") { runner.reset() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
        }
        .paperBackground()
        .task {
            guard !saved, let start = runner.started else { return }
            saved = true
            await health.logBreathing(from: start, to: start.addingTimeInterval(runner.elapsed))
        }
    }
}
