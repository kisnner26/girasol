#if GIRASOL_GAME_CENTER
import GameKit
#endif

/// autentica al jugador local y sube puntajes a las tablas de Game Center.
/// en watchOS no hay `GKAccessPoint` ni vista propia de tablas: el jugador las ve en el Game Center de su iPhone
/// (o en la app Juegos), la marca aparece sola ahi una vez autenticado. hay que crear en App Store Connect
/// (Funciones > Game Center) una tabla de clasificacion por cada id de `LeaderboardID` abajo.
@MainActor
final class GameCenterService {
    static let shared = GameCenterService()

    enum LeaderboardID {
        static let pistol = "girasol.pistol"
        static let darts = "girasol.darts"
        static let tennis = "girasol.tennis"
        static let airBasketball = "girasol.airbasketball"
    }

    private(set) var isAuthenticated = false

    func authenticate() {
#if GIRASOL_GAME_CENTER
        GKLocalPlayer.local.authenticateHandler = { [weak self] error in
            Task { @MainActor in
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
#endif
    }

    /// sube el puntaje si el jugador esta autenticado; falla en silencio si no (sin internet, no ha iniciado sesion, etc).
    func submit(score: Int, leaderboardID: String) {
#if GIRASOL_GAME_CENTER
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { _ in }
#endif
    }
}
