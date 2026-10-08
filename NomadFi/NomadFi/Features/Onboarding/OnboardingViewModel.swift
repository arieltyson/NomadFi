import Foundation
import SwiftData

/// Manages the onboarding flow state, user selections, and SwiftData persistence.
@MainActor
@Observable
final class OnboardingViewModel {

    // MARK: - Flow State

    enum Step: Int, CaseIterable, Sendable {
        case welcome
        case jurisdictions
        case currency
        case accounts
    }

    var currentStep: Step = .welcome

    // MARK: - Jurisdiction Selection

    var selectedJurisdictions: [JurisdictionInfo] = []

    var canProceedFromJurisdictions: Bool {
        !selectedJurisdictions.isEmpty
    }

    // MARK: - Currency Configuration

    var homeCurrencyCode: CurrencyCode = .usd

    /// The unique set of currencies derived from selected jurisdictions.
    var availableCurrencies: [CurrencyCode] {
        Array(Set(selectedJurisdictions.map(\.currencyCode))).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Account Entry

    var accountName: String = ""
    var accountInstitution: String = ""
    var accountType: AccountType = .checking
    var accountCurrency: CurrencyCode = .usd
    var accountCurrentBalanceText: String = ""
    var accountCreditLimitText: String = ""
    var accountAvailableCreditText: String = ""
    var addedAccounts: [AccountDraft] = []

    var canAddAccount: Bool {
        !accountName.trimmingCharacters(in: .whitespaces).isEmpty
            && !accountInstitution.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Navigation

    func advance() {
        guard let nextIndex = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }

    func goBack() {
        guard let previousIndex = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousIndex
    }

    // MARK: - Jurisdiction Actions

    func toggleJurisdiction(_ jurisdiction: JurisdictionInfo) {
        if let index = selectedJurisdictions.firstIndex(of: jurisdiction) {
            selectedJurisdictions.remove(at: index)
        } else {
            selectedJurisdictions.append(jurisdiction)
        }

        // Default home currency to the first selected jurisdiction's currency
        if let first = selectedJurisdictions.first {
            homeCurrencyCode = first.currencyCode
        }
    }

    func isSelected(_ jurisdiction: JurisdictionInfo) -> Bool {
        selectedJurisdictions.contains(jurisdiction)
    }

    // MARK: - Account Actions

    func addCurrentAccount() {
        guard canAddAccount else { return }

        let currentBalance = Self.parseOptional(accountCurrentBalanceText)
        let creditLimit = accountType.isCreditCard
            ? Self.parseOptional(accountCreditLimitText)
            : nil
        let availableCredit = accountType.isCreditCard
            ? Self.parseOptional(accountAvailableCreditText)
            : nil

        let jurisdiction = selectedJurisdictions.first { $0.currencyCode == accountCurrency }?.id ?? ""

        let draft = AccountDraft(
            name: accountName.trimmingCharacters(in: .whitespaces),
            institutionName: accountInstitution.trimmingCharacters(in: .whitespaces),
            accountType: accountType,
            currencyCode: accountCurrency,
            jurisdiction: jurisdiction,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            availableCredit: availableCredit
        )

        addedAccounts.append(draft)
        resetAccountForm()
    }

    func removeAccount(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            addedAccounts.remove(at: index)
        }
    }

    // MARK: - Persistence

    /// Saves all onboarding data to SwiftData and marks onboarding complete.
    func completeOnboarding(modelContext: ModelContext) {
        // Save jurisdiction profiles
        for (index, jurisdiction) in selectedJurisdictions.enumerated() {
            let profile = JurisdictionProfile(
                countryCode: jurisdiction.id,
                countryName: jurisdiction.name,
                currencyCode: jurisdiction.currencyCode,
                isHome: jurisdiction.currencyCode == homeCurrencyCode,
                displayOrder: index
            )
            modelContext.insert(profile)
        }

        // Save accounts
        for draft in addedAccounts {
            let hasSnapshot = draft.currentBalance != nil || draft.availableCredit != nil
            let account = Account(
                name: draft.name,
                institutionName: draft.institutionName,
                accountType: draft.accountType,
                currencyCode: draft.currencyCode,
                jurisdiction: draft.jurisdiction,
                creditLimit: draft.creditLimit,
                currentBalance: draft.currentBalance,
                availableCredit: draft.availableCredit,
                financialSnapshotUpdatedAt: hasSnapshot ? .now : nil,
                financialSnapshotSource: hasSnapshot ? .userSnapshot : nil
            )
            modelContext.insert(account)
        }
    }

    // MARK: - Private

    private func resetAccountForm() {
        accountName = ""
        accountInstitution = ""
        accountType = .checking
        accountCurrentBalanceText = ""
        accountCreditLimitText = ""
        accountAvailableCreditText = ""
    }

    private static func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0 else {
            return nil
        }
        return value
    }
}

// MARK: - Account Draft

/// A temporary account representation before SwiftData persistence.
struct AccountDraft: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let institutionName: String
    let accountType: AccountType
    let currencyCode: CurrencyCode
    let jurisdiction: String
    let creditLimit: Double?
    let currentBalance: Double?
    let availableCredit: Double?
}
