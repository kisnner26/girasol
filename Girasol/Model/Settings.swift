import Foundation
import Observation
import SunKit

@Observable
final class Settings {
    private let defaults = UserDefaults.standard

    var skin: SkinType {
        didSet { defaults.set(skin.rawValue, forKey: "girasol.skin") }
    }
    var sunscreen: Sunscreen {
        didSet { defaults.set(sunscreen.spf, forKey: "girasol.spf") }
    }
    var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: "girasol.alerts") }
    }

    var reapplyReminders: Bool {
        didSet { defaults.set(reapplyReminders, forKey: "girasol.reapply") }
    }

    init() {
        skin = SkinType(rawValue: defaults.integer(forKey: "girasol.skin")) ?? .iii
        sunscreen = Sunscreen(spf: defaults.integer(forKey: "girasol.spf"))
        alertsEnabled = defaults.object(forKey: "girasol.alerts") as? Bool ?? true
        reapplyReminders = defaults.object(forKey: "girasol.reapply") as? Bool ?? true
    }
}
