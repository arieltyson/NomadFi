import CoreLocation
import Observation

/// Coordinates location authorization state for onboarding priming.
@MainActor
@Observable
final class LocationPermissionPrimingViewModel {

    // MARK: - Public State

    var authorizationStatus: CLAuthorizationStatus
    var isRequestingPermission = false
    var hasRequestedPermission = false

    // MARK: - Private State

    private let locationManager = CLLocationManager()

    // MARK: - Lifecycle

    init() {
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Derived State

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse
            || authorizationStatus == .authorizedAlways
    }

    var isDeniedOrRestricted: Bool {
        authorizationStatus == .denied
            || authorizationStatus == .restricted
    }

    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    var canShowAnimatedPrompt: Bool {
        isNotDetermined && !isRequestingPermission
    }

    // MARK: - Actions

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        refreshAuthorizationStatus()

        guard isNotDetermined else { return }

        hasRequestedPermission = true
        isRequestingPermission = true
        locationManager.requestWhenInUseAuthorization()

        Task {
            await waitForAuthorizationResolution()
        }
    }

    // MARK: - Private Helpers

    private func waitForAuthorizationResolution() async {
        // Poll status briefly because CLLocationManager authorization callbacks
        // are not guaranteed to synchronize with this onboarding surface timing.
        for _ in 0..<30 {
            refreshAuthorizationStatus()

            if !isNotDetermined {
                isRequestingPermission = false
                return
            }

            try? await Task.sleep(for: .milliseconds(150))
        }

        isRequestingPermission = false
    }
}
