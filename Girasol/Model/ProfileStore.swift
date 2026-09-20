import Foundation
import Observation
import HealthCore

@MainActor
@Observable
final class ProfileStore {
    static let shared = ProfileStore()
    private static let key = "girasol.profile"

    var profile: Profile {
        didSet {
            let clean = profile.sanitized()
            Haptics.enabled = clean.haptics
            Sfx.shared.enabled = clean.sounds
            if let data = try? JSONEncoder().encode(clean) { UserDefaults.standard.set(data, forKey: Self.key) }
        }
    }

    private init() {
        let p = Self.load()
        profile = p
        Haptics.enabled = p.haptics
        Sfx.shared.enabled = p.sounds
    }

    /// lectura sin actor: la usan tambien los atajos del boton de accion.
    nonisolated static func load() -> Profile {
        guard let data = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(Profile.self, from: data) else { return Profile() }
        return p.sanitized()
    }
}
