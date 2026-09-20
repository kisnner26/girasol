import CoreLocation

/// ubicacion aproximada, solo mientras la app esta en uso.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Failure: Error { case denied, unavailable }

    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocation, Error>?
    private var awaitingAuth: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isDenied: Bool { [.denied, .restricted].contains(manager.authorizationStatus) }

    func current() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            await withCheckedContinuation { awaitingAuth = $0 }
        }
        if isDenied { throw Failure.denied }
        pending?.resume(throwing: Failure.unavailable)   // una sola peticion a la vez
        return try await withCheckedThrowingContinuation { c in
            pending = c
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            awaitingAuth?.resume()
            awaitingAuth = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            pending?.resume(returning: last)
            pending = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            pending?.resume(throwing: error)
            pending = nil
        }
    }
}
