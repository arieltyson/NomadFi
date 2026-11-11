import Foundation
import Testing
@testable import NomadFi

@MainActor
struct BankConnectionsRouteTests {

    @Test func requestSelectsSettingsAndQueuesBankConnections() throws {
        let suite = "nomadfi.tests.route.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        BankConnectionsRoute.request(in: defaults)

        #expect(defaults.string(forKey: MainTabSelection.storageKey) == MainTabSelection.settings.rawValue)
        #expect(defaults.bool(forKey: BankConnectionsRoute.storageKey))
    }
}
