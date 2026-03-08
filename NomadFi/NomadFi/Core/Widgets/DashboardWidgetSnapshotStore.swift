import Foundation
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Controls persistence and timeline reload behavior for dashboard widgets.
struct DashboardWidgetSnapshotStore {

    enum ReloadPolicy {
        case scheduledOnly
        case significantChange
    }

    private static let logger = Logger(
        subsystem: "com.nomadfi.app",
        category: "DashboardWidgetSnapshotStore"
    )

    private let defaults: UserDefaults?

    init(
        defaults: UserDefaults? = UserDefaults(
            suiteName: NomadFiWidgetSharedConstants.appGroupIdentifier
        )
    ) {
        self.defaults = defaults
    }

    func loadSnapshot() -> DashboardWidgetSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: NomadFiWidgetSharedConstants.dashboardSnapshotKey) else {
            return nil
        }

        do {
            let snapshot = try JSONDecoder().decode(DashboardWidgetSnapshot.self, from: data)
            return snapshot
        } catch {
            Self.logger.error("Failed to decode widget snapshot: \(error.localizedDescription)")
            return nil
        }
    }

    func persist(_ snapshot: DashboardWidgetSnapshot, reloadPolicy: ReloadPolicy) {
        guard let defaults else { return }

        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: NomadFiWidgetSharedConstants.dashboardSnapshotKey)

            if reloadPolicy == .significantChange {
                reloadWidgetTimelines()
            }
        } catch {
            Self.logger.error("Failed to encode widget snapshot: \(error.localizedDescription)")
        }
    }

    func clearSnapshot() {
        guard let defaults else { return }

        defaults.removeObject(forKey: NomadFiWidgetSharedConstants.dashboardSnapshotKey)
        reloadWidgetTimelines()
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "NomadFiDashboardWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "NomadFiLockScreenWidget")
        #endif
    }
}
