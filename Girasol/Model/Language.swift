import Foundation
import Observation
import SwiftUI

enum LanguageChoice: String, CaseIterable {
    case system, es, en
    /// los idiomas se nombran en su propio idioma; solo "sistema" se traduce.
    var title: LocalizedStringKey {
        switch self {
        case .system: "sistema"
        case .es: "español"
        case .en: "english"
        }
    }
}

/// idioma de la app. por defecto sigue al del reloj; se puede fijar a mano en ajustes.
/// los textos salen de los .lproj de la app, asi que basta elegir el paquete de idioma correcto.
enum Lang {
    nonisolated(unsafe) private(set) static var code = "en"
    nonisolated(unsafe) private(set) static var bundle = Bundle.main

    static var locale: Locale { Locale(identifier: code) }
    static var calendar: Calendar { var c = Calendar.current; c.locale = locale; return c }

    static let supported = ["en", "es"]

    static func apply(_ choice: LanguageChoice) {
        let wanted = choice == .system ? (Bundle.main.preferredLocalizations.first ?? "en") : choice.rawValue
        code = supported.contains(wanted) ? wanted : "en"
        bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

/// texto localizado en el idioma elegido en la app (no el del sistema).
func loc(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: Lang.bundle, locale: Lang.locale)
}

@MainActor
@Observable
final class LanguageSettings {
    static let shared = LanguageSettings()

    var choice: LanguageChoice {
        didSet {
            UserDefaults.standard.set(choice.rawValue, forKey: "girasol.language")
            Lang.apply(choice)
            WidgetSync.language(Lang.code)
        }
    }

    private init() {
        choice = LanguageChoice(rawValue: UserDefaults.standard.string(forKey: "girasol.language") ?? "") ?? .system
        Lang.apply(choice)
    }
}
