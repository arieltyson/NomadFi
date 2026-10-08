import Foundation
import OSLog
import SwiftData

/// Manages the onboarding flow state, user selections, and SwiftData persistence.
@MainActor
@Observable
final class OnboardingViewModel {

    private static let logger = Logger(subsystem: "com.nomadfi.app", category: "Onboarding")

    // MARK: - Flow State

    /// The steps pushed onto the navigation stack after the welcome screen.
    enum Step: Hashable, Sendable {
        case jurisdictions
        case currency
        case accounts
    }

    /// The navigation path. The welcome screen is the root, so an empty
    /// path means the user is on the welcome screen.
    var path: [Step] = []

    /// The step that follows the visible one, or `nil` on the last step.
    ///
    /// The home currency step is skipped when the selected jurisdictions
    /// share a single currency, since there is nothing to choose.
    var nextStep: Step? {
        switch path.last {
        case nil: .jurisdictions
        case .jurisdictions: needsHomeCurrencyChoice ? .currency : .accounts
        case .currency: .accounts
        case .accounts: nil
        }
    }

    /// True when saving the onboarding data failed and the user should retry.
    var isShowingSaveFailure = false

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

    var needsHomeCurrencyChoice: Bool {
        availableCurrencies.count > 1
    }

    /// The jurisdiction marked as home: the first selected jurisdiction
    /// using the home currency, so countries sharing a currency never
    /// produce more than one home.
    var homeJurisdiction: JurisdictionInfo? {
        selectedJurisdictions.first { $0.currencyCode == homeCurrencyCode } ?? selectedJurisdictions.first
    }

    // MARK: - Account Entry

    var accountName: String = ""
    var accountInstitution: String = ""
    var accountType: AccountType = .checking
    var accountCurrentBalanceText: String = ""
    var accountCreditLimitText: String = ""
    var accountAvailableCreditText: String = ""

    /// The jurisdiction the account being entered belongs to. Falls back
    /// to the home jurisdiction until the user picks another one.
    var accountJurisdiction: JurisdictionInfo? {
        selectedJurisdictions.first { $0.id == preferredAccountJurisdictionID } ?? homeJurisdiction
    }

    /// Picker selection for `accountJurisdiction`.
    var accountJurisdictionID: JurisdictionInfo.ID {
        get { accountJurisdiction?.id ?? "" }
        set { preferredAccountJurisdictionID = newValue }
    }

    /// The account's country only needs asking when there is more than one.
    var showsAccountJurisdictionPicker: Bool {
        selectedJurisdictions.count > 1
    }

    /// Accounts in the currently selected jurisdictions. Accounts in a
    /// jurisdiction the user deselected are kept aside rather than
    /// deleted, so reselecting it brings them back.
    var addedAccounts: [AccountDraft] {
        let selectedIDs = Set(selectedJurisdictions.map(\.id))
        return accountDrafts.filter { selectedIDs.contains($0.jurisdiction) }
    }

    var canAddAccount: Bool {
        accountJurisdiction != nil
            && !accountName.trimmingCharacters(in: .whitespaces).isEmpty
            && !accountInstitution.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var preferredAccountJurisdictionID: JurisdictionInfo.ID?
    private var accountDrafts: [AccountDraft] = []

    // MARK: - Navigation

    func advance() {
        guard let nextStep else { return }
        path.append(nextStep)
    }

    // MARK: - Jurisdiction Actions

    func toggleJurisdiction(_ jurisdiction: JurisdictionInfo) {
        if let index = selectedJurisdictions.firstIndex(of: jurisdiction) {
            selectedJurisdictions.remove(at: index)
        } else {
            selectedJurisdictions.append(jurisdiction)
        }

        // Keep the user's home currency unless its last jurisdiction was
        // deselected; then default to the first selected jurisdiction's.
        if !availableCurrencies.contains(homeCurrencyCode), let first = selectedJurisdictions.first {
            homeCurrencyCode = first.currencyCode
        }
    }

    func isSelected(_ jurisdiction: JurisdictionInfo) -> Bool {
        selectedJurisdictions.contains(jurisdiction)
    }

    // MARK: - Account Actions

    func addCurrentAccount() {
        guard canAddAccount, let jurisdiction = accountJurisdiction else { return }

        let currentBalance = Self.parseOptional(accountCurrentBalanceText)
        let creditLimit = accountType.isCreditCard
            ? Self.parseOptional(accountCreditLimitText)
            : nil
        let availableCredit = accountType.isCreditCard
            ? Self.parseOptional(accountAvailableCreditText)
            : nil

        let draft = AccountDraft(
            name: accountName.trimmingCharacters(in: .whitespaces),
            institutionName: accountInstitution.trimmingCharacters(in: .whitespaces),
            accountType: accountType,
            currencyCode: jurisdiction.currencyCode,
            jurisdiction: jurisdiction.id,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            availableCredit: availableCredit
        )

        accountDrafts.append(draft)
        resetAccountForm()
    }

    /// Removes accounts at `offsets` within `addedAccounts`.
    func removeAccount(at offsets: IndexSet) {
        let removedIDs = Set(offsets.map { addedAccounts[$0].id })
        accountDrafts.removeAll { removedIDs.contains($0.id) }
    }

    // MARK: - Persistence

    /// Saves all onboarding data to SwiftData.
    ///
    /// - Returns: `true` once the data is saved. On failure nothing is
    ///   kept, `isShowingSaveFailure` is set, and onboarding should stay
    ///   open so the user can retry.
    func completeOnboarding(modelContext: ModelContext) -> Bool {
        let homeID = homeJurisdiction?.id

        for (index, jurisdiction) in selectedJurisdictions.enumerated() {
            let profile = JurisdictionProfile(
                countryCode: jurisdiction.id,
                countryName: jurisdiction.name,
                currencyCode: jurisdiction.currencyCode,
                isHome: jurisdiction.id == homeID,
                displayOrder: index
            )
            modelContext.insert(profile)
        }

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

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            Self.logger.error("Failed to save onboarding data: \(error.localizedDescription, privacy: .public)")
            isShowingSaveFailure = true
            return false
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
