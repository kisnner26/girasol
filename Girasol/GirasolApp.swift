import SwiftUI
import WatchKit

@main
struct GirasolApp: App {
    @State private var model = AppModel()
    @State private var health = HealthModel()
    @State private var runner = BreathingRunner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(health)
                .environment(runner)
                .task { scheduleRefresh() }
        }
        .backgroundTask(.appRefresh("girasol.refresh")) {
            await model.refresh()
            await health.refresh()
            await MainActor.run { scheduleRefresh() }
        }
    }

    /// el sistema decide cuando; ~cada 30 min como maximo.
    private func scheduleRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(30 * 60), userInfo: nil) { _ in }
    }
}
