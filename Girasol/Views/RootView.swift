import SwiftUI
import HealthCore
import SunKit

struct RootView: View {
    @Environment(AppModel.self) private var sun
    @Environment(HealthModel.self) private var health
    @Environment(\.scenePhase) private var phase
    @State private var splash = true
    private let language = LanguageSettings.shared

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if health.profile.onboarded {
                MainStack().id(language.choice)
            } else {
                NavigationStack { OnboardingView() }.id(language.choice)
            }
            if splash {
                SplashView().transition(.opacity)
            }
        }
        .environment(\.colorScheme, Appearance.shared.choice == .night ? .dark : .light)
        .environment(\.locale, Lang.locale)
        .task {
            async let warm: () = refreshAll()
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.6)) { splash = false }
            await warm
        }
        .onChange(of: phase) { _, new in
            if new == .active { Task { await refreshAll() } }
        }
        .onChange(of: health.profile.onboarded) { _, done in
            if done { Task { await refreshAll() } }
        }
    }

    private func refreshAll() async {
        guard health.profile.onboarded else { return }
        async let s: () = sun.refreshIfStale()
        async let h: () = health.refresh()
        _ = await (s, h)
    }
}

struct MainStack: View {
    @Environment(BreathingRunner.self) private var runner

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .sun: SunHubView()
                    case .water: WaterView()
                    case .food: FoodView()
                    case .body: BodyView()
                    case .breathe: BreatheView()
                    case .focus: FocusView()
                    case .games: GamesView()
                    case .settings: SettingsView()
                    case .week: WeekView()
                    case .sleep: SleepView()
                    case .airBasketball: AirBasketballView()
                    case .darts: DartsView()
                    case .pistol: PistolView()
                    case .tennis: TennisView()
                    case .bubbles: BubblesView()
                    case .calibrate: AimCalibrationView()
                    }
                }
                .navigationDestination(for: SettingsSection.self) { SettingsDetail(section: $0) }
        }
        .containerBackground(Palette.paper, for: .navigation)
    }
}

/// las tres pantallas de sol, como paginas verticales.
struct SunHubView: View {
    var body: some View {
        TabView {
            NowView()
            ExposureView()
            TodayView()
        }
        .tabViewStyle(.verticalPage)
    }
}

/// la pantalla de carga de la pagina de las flores: una flor que gira despacio.
struct SplashView: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            VStack(spacing: 10) {
                SunflowerGauge(uvi: 0, petals: 8)
                    .frame(width: 56, height: 56)
                    .opacity(0.5)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: spin)
                Text("girasol")
                    .font(.serif(15, italic: true))
                    .tracking(4)
                    .foregroundStyle(Palette.mid)
            }
        }
        .onAppear { spin = true }
    }
}
