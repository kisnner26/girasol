import SwiftUI
import HealthCore

/// temporizador de enfoque por rondas: trabajas, descansas y, en el descanso, un toque registra el agua.
struct FocusView: View {
    @Environment(HealthModel.self) private var health
    @AppStorage("girasol.focus.plan") private var planID = "classic"
    private let runner = FocusRunner.shared

    var body: some View {
        if let session = runner.session {
            RunningFocus(session: session)
        } else {
            setup
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(spacing: 10) {
                Caption("enfoque")
                Text("una cosa a la vez").font(.serif(15, italic: true)).foregroundStyle(Palette.ink)
                ChoiceRow(title: "ritmo",
                          options: FocusPlan.all.map { ($0.id, "\($0.title) · \($0.detail) min") },
                          selection: $planID)
                Button("empezar") { runner.start(plan: .plan(id: planID)) }
                    .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                Text("trabajas por rondas y el reloj te avisa con un toque cuando toca descansar. en el descanso puedes anotar un vaso de agua.")
                    .font(.serif(10, italic: true)).foregroundStyle(Palette.mid).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
        }
        .paperBackground()
    }
}

private struct RunningFocus: View {
    @Environment(HealthModel.self) private var health
    let session: FocusSession
    @State private var drank = false
    private let runner = FocusRunner.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let m = session.moment(at: context.date)
            ScrollView {
                VStack(spacing: 6) {
                    Caption(verbatim: m.phase.label)
                    ZStack {
                        Circle().stroke(Palette.ink.opacity(0.15), lineWidth: 5)
                        Circle().trim(from: 0, to: m.progress)
                            .stroke(Palette.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(clock(m.remaining)).font(.serif(30, italic: true)).foregroundStyle(Palette.ink)
                            Caption(verbatim: loc("ronda \(m.round)"))
                        }
                    }
                    .frame(width: 118, height: 118)
                    .padding(.vertical, 4)

                    if m.phase.isBreak {
                        Button(drank ? "anotado" : "tomé agua") {
                            guard !drank else { return }
                            drank = true
                            Task { await health.addWater(health.profile.glassMl) }
                        }
                        .buttonStyle(InkButtonStyle()).doubleTapPrimary()
                    }
                    if session.isPaused {
                        Button("seguir") { runner.resume() }.buttonStyle(InkButtonStyle())
                    } else {
                        Button("pausar") { runner.pause() }.buttonStyle(QuietButtonStyle())
                    }
                    Button("siguiente") { runner.skip() }.buttonStyle(QuietButtonStyle())
                    Button("terminar") { runner.stop() }.buttonStyle(QuietButtonStyle())
                }
                .padding(.horizontal, 8)
                .onChange(of: m.phase) { _, new in
                    drank = false
                    Haptics.play(new.isBreak ? .success : .start)
                }
            }
        }
        .paperBackground()
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
