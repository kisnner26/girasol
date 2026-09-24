import SwiftUI
import HealthCore

struct FocusView: View {
    @Environment(HealthModel.self) private var health
    @Environment(FocusRunner.self) private var runner
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
                Caption("concentración")
                LineIcon(kind: .target).frame(width: 46, height: 46)
                Text("un bloque para trabajar sin distracciones").font(.serif(13, italic: true)).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                ChoiceRow(title: "ritmo",
                          options: FocusPattern.all.map { ($0.id, "\($0.title) · \($0.detail)") },
                          selection: $store.profile.focusPattern)
                ChoiceRow(title: "duración",
                          options: [15, 30, 50, 90].map { ($0, $0 == 90 ? loc("1 h 30") : loc("\($0) minutos")) },
                          selection: $store.profile.focusMinutes)
                Button("empezar") {
                    let p = health.profile
                    runner.begin(pattern: .pattern(id: p.focusPattern), minutes: p.focusMinutes)
                }
                .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                Text("vibra al empezar cada bloque de trabajo y cada descanso.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
    }
}

private struct SessionView: View {
    @Environment(FocusRunner.self) private var runner

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let t = runner.elapsed
            let m = runner.session?.moment(at: t)
            VStack(spacing: 8) {
                Text(m?.phase.label ?? "").font(.serif(20, italic: true)).foregroundStyle(Palette.ink)
                Text(remainingText(m?.remaining ?? 0)).font(.serif(38)).foregroundStyle(Palette.ink).minimumScaleFactor(0.6)
                if let m {
                    Caption(verbatim: m.phase == .work ? loc("bloque \(m.cycleIndex + 1)") : loc("descansa un momento"))
                }
                Button("terminar") { runner.finish(completed: false) }.buttonStyle(QuietButtonStyle())
            }
        }
        .paperBackground()
        .navigationBarBackButtonHidden(true)
    }

    private func remainingText(_ s: Double) -> String {
        let n = Int(s.rounded(.up))
        return "\(n / 60):\(String(format: "%02d", n % 60))"
    }
}

private struct FinishedView: View {
    @Environment(FocusRunner.self) private var runner
    @Environment(HealthModel.self) private var health
    @State private var saved = false

    var body: some View {
        let mins = Int((runner.elapsed / 60).rounded())
        VStack(spacing: 8) {
            Sprig().frame(width: 40, height: 56)
            Text(runner.completed ? "buen trabajo" : "sesión corta").font(.serif(18, italic: true)).foregroundStyle(Palette.ink)
            Caption("\(mins) min de concentración")
            Button("listo") { runner.reset() }.buttonStyle(InkButtonStyle()).doubleTapPrimary()
        }
        .paperBackground()
        .task {
            guard !saved, let start = runner.started else { return }
            saved = true
            await health.logFocus(from: start, to: start.addingTimeInterval(runner.elapsed))
        }
    }
}
