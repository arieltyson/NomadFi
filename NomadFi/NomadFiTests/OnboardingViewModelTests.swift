// OnboardingViewModelTests.swift
// NomadFi
//
// Coverage for onboarding step routing, home jurisdiction selection,
// account jurisdiction assignment, and persistence.

import Foundation
import SwiftData
import Testing

@testable import NomadFi

@MainActor
struct OnboardingViewModelTests {

    // MARK: - Helpers

    private func jurisdiction(_ id: String) throws -> JurisdictionInfo {
        try #require(JurisdictionInfo.supported.first { $0.id == id })
    }

    private func makeViewModel(selecting ids: [String]) throws -> OnboardingViewModel {
        let viewModel = OnboardingViewModel()
        for id in ids {
            viewModel.toggleJurisdiction(try jurisdiction(id))
        }
        return viewModel
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            Subscription.self,
            TaxDocument.self,
            Budget.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func addAccount(named name: String, to viewModel: OnboardingViewModel) {
        viewModel.accountName = name
        viewModel.accountInstitution = "Bank"
        viewModel.addCurrentAccount()
    }

    // MARK: - Step Routing

    @Test("A single jurisdiction can proceed and skips the home currency step")
    func singleJurisdictionSkipsCurrencyStep() throws {
        let viewModel = try makeViewModel(selecting: ["IN"])

        #expect(viewModel.canProceedFromJurisdictions)

        viewModel.advance()
        viewModel.advance()

        #expect(viewModel.path == [.jurisdictions, .accounts])
    }

    @Test("Jurisdictions sharing one currency skip the home currency step")
    func sharedCurrencySkipsCurrencyStep() throws {
        let viewModel = try makeViewModel(selecting: ["DE", "FR"])

        viewModel.advance()
        viewModel.advance()

        #expect(viewModel.path == [.jurisdictions, .accounts])
    }

    @Test("Multiple currencies route through the home currency step")
    func multipleCurrenciesShowCurrencyStep() throws {
        let viewModel = try makeViewModel(selecting: ["TT", "CA"])

        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()

        #expect(viewModel.path == [.jurisdictions, .currency, .accounts])
    }

    @Test("No jurisdictions cannot proceed")
    func noJurisdictionsCannotProceed() {
        #expect(!OnboardingViewModel().canProceedFromJurisdictions)
    }

    // MARK: - Home Currency

    @Test("Toggling jurisdictions keeps a still-valid home currency")
    func togglingKeepsHomeCurrency() throws {
        let viewModel = try makeViewModel(selecting: ["TT", "CA"])
        viewModel.homeCurrencyCode = .cad

        viewModel.toggleJurisdiction(try jurisdiction("US"))

        #expect(viewModel.homeCurrencyCode == .cad)
    }

    @Test("Deselecting the home currency's jurisdiction falls back to the first selection")
    func deselectingHomeFallsBack() throws {
        let viewModel = try makeViewModel(selecting: ["TT", "CA"])
        viewModel.homeCurrencyCode = .cad

        viewModel.toggleJurisdiction(try jurisdiction("CA"))

        #expect(viewModel.homeCurrencyCode == .ttd)
    }

    // MARK: - Account Jurisdiction

    @Test("Accounts default to the home jurisdiction and its currency")
    func accountDefaultsToHome() throws {
        let viewModel = try makeViewModel(selecting: ["IN"])

        addAccount(named: "Savings", to: viewModel)

        let draft = try #require(viewModel.addedAccounts.first)
        #expect(draft.jurisdiction == "IN")
        #expect(draft.currencyCode == .inr)
        #expect(!viewModel.showsAccountJurisdictionPicker)
    }

    @Test("Accounts use the picked jurisdiction even when currencies are shared")
    func accountUsesPickedJurisdiction() throws {
        let viewModel = try makeViewModel(selecting: ["DE", "FR"])

        viewModel.accountJurisdictionID = "FR"
        addAccount(named: "Compte courant", to: viewModel)

        let draft = try #require(viewModel.addedAccounts.first)
        #expect(draft.jurisdiction == "FR")
        #expect(draft.currencyCode == .eur)
        #expect(viewModel.showsAccountJurisdictionPicker)
    }

    @Test("Accounts in a deselected jurisdiction are hidden and return when reselected")
    func deselectedJurisdictionAccountsAreSetAside() throws {
        let viewModel = try makeViewModel(selecting: ["TT", "CA"])
        viewModel.accountJurisdictionID = "CA"
        addAccount(named: "Chequing", to: viewModel)

        viewModel.toggleJurisdiction(try jurisdiction("CA"))
        #expect(viewModel.addedAccounts.isEmpty)

        viewModel.toggleJurisdiction(try jurisdiction("CA"))
        #expect(viewModel.addedAccounts.map(\.name) == ["Chequing"])
    }

    @Test("Removing an account by offset removes the visible account")
    func removeAccountByOffset() throws {
        let viewModel = try makeViewModel(selecting: ["TT", "CA"])
        viewModel.accountJurisdictionID = "CA"
        addAccount(named: "Hidden", to: viewModel)
        viewModel.accountJurisdictionID = "TT"
        addAccount(named: "First", to: viewModel)
        addAccount(named: "Second", to: viewModel)
        viewModel.toggleJurisdiction(try jurisdiction("CA"))

        viewModel.removeAccount(at: [0])

        #expect(viewModel.addedAccounts.map(\.name) == ["Second"])
    }

    // MARK: - Persistence

    @Test("Shared-currency jurisdictions save exactly one home")
    func savesSingleHome() throws {
        let viewModel = try makeViewModel(selecting: ["DE", "FR"])
        let context = try makeContext()

        #expect(viewModel.completeOnboarding(modelContext: context))

        let profiles = try context.fetch(FetchDescriptor<JurisdictionProfile>())
        #expect(profiles.filter(\.isHome).map(\.countryCode) == ["DE"])
    }

    @Test("Completing onboarding saves profiles and accounts")
    func savesProfilesAndAccounts() throws {
        let viewModel = try makeViewModel(selecting: ["IN"])
        addAccount(named: "Savings", to: viewModel)
        let context = try makeContext()

        #expect(viewModel.completeOnboarding(modelContext: context))
        #expect(!context.hasChanges)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.map(\.jurisdiction) == ["IN"])
        #expect(!viewModel.isShowingSaveFailure)
    }
}
