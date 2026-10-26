import SwiftUI

/// respeta la atenuacion y suspension de watchOS; nunca solicita ejecucion adicional.
private struct GameActivityModifier: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    let onSuspend: () -> Void

    private var active: Bool { phase == .active && !dimmed }

    func body(content: Content) -> some View {
        content.onChange(of: active) { _, active in
            if !active { suspend() }
        }
        .onDisappear { suspend() }
    }

    private func suspend() {
        onSuspend()
        Sfx.shared.stop()
    }
}

extension View {
    func gameActivity(onSuspend: @escaping () -> Void) -> some View {
        modifier(GameActivityModifier(onSuspend: onSuspend))
    }
}
