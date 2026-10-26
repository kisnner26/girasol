import CoreLocation
import Observation

/// hacia donde apunta la muñeca, para la brujula de sombra. solo vive mientras esa pantalla esta abierta.
@MainActor
@Observable
final class HeadingService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    /// grados desde el norte magnetico, 0...360.
    var heading: Double = 0
    var available = true

    override init() {
        super.init()
        manager.delegate = self
        available = CLLocationManager.headingAvailable()
    }

    func start() {
        guard available else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = h }
    }
}
