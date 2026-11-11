import Foundation
import SwiftData
import Testing
@testable import NomadFi

@MainActor
struct DataWipeTests {

    @Test func deleteAllReturnsToOnboardingAndClearsTheWidgetSnapshot() throws {
        let suite = "nomadfi.tests.wipe.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suite))
        let shared = try #require(UserDefaults(suiteName: "\(suite).group"))
        defer {
            preferences.removePersistentDomain(forName: suite)
            shared.removePersistentDomain(forName: "\(suite).group")
        }
        preferences.set(true, forKey: OnboardingPreferences.completedKey)
        shared.set(Data("snapshot".utf8), forKey: NomadFiWidgetSharedConstants.dashboardSnapshotKey)

        let container = try SwiftDataTestContainerFactory.makeFullSchemaContainer()
        let context = ModelContext(container)
        context.insert(Account(name: "Everyday", accountType: .checking, currencyCode: .cad, balance: 100))
        try context.save()

        DataGovernancePolicy.deleteAllUserData(
            in: context,
            notificationManager: NotificationManager(),
            preferences: preferences,
            sharedDefaults: shared
        )

        #expect(preferences.bool(forKey: OnboardingPreferences.completedKey) == false)
        #expect(preferences.object(forKey: OnboardingPreferences.completedKey) != nil)
        #expect(shared.data(forKey: NomadFiWidgetSharedConstants.dashboardSnapshotKey) == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Account>()) == 0)
    }
}
