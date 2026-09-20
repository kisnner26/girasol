import Foundation
import Observation

enum ThemeChoice: String, CaseIterable {
    case paper, night
    var title: String { self == .paper ? loc("papel") : loc("noche") }
}

/// tema elegido. es un singleton observable para que `Palette` cambie los colores de toda la interfaz.
@Observable
final class Appearance {
    static let shared = Appearance()

    var choice: ThemeChoice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "girasol.theme") }
    }

    private init() {
        choice = ThemeChoice(rawValue: UserDefaults.standard.string(forKey: "girasol.theme") ?? "") ?? .paper
    }
}
