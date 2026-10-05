import SwiftUI

/// Form sheet for adding an account from Settings after onboarding.
///
/// The amount section is account-type-aware: credit cards ask for a
/// credit limit plus optional current balance and available credit;
/// deposit, wallet, and investment accounts ask for an optional current
/// balance. A single field is never overloaded for both balance and
/// limit — the two are distinct financial facts.
struct SettingsAddAccountSheet: View {

    let jurisdictions: [JurisdictionProfile]
    let onSave: (SettingsAccountDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var draft = SettingsAccountDraft()

    enum Field {
        case name
        case institution
        case currentBalance
        case creditLimit
        case availableCredit
        case foreignTransactionFee
    }

    /// Moves focus through the form's text fields so the on-screen
    /// Return key advances through name → institution. Amount fields
    /// use `.decimalPad`, which has no Return key, so the shared
    /// keyboard Done toolbar dismisses them.
    private func advanceFocus(from field: Field) {
        switch field {
        case .name: focusedField = .institution
        case .institution:
            focusedField = draft.accountType.isCreditCard ? .creditLimit : .currentBalance
        default: focusedField = nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $draft.name)
                        .focused($focusedField, equals: .name)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { advanceFocus(from: .name) }

                    TextField("Institution", text: $draft.institutionName)
                        .focused($focusedField, equals: .institution)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { advanceFocus(from: .institution) }
                }

                Section("Type & Jurisdiction") {
                    Picker("Account Type", selection: $draft.accountType) {
                        ForEach(AccountType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    Picker("Jurisdiction", selection: $draft.jurisdictionCode) {
                        Text("None")
                            .tag("")

                        ForEach(jurisdictions) { jurisdiction in
                            Text(jurisdiction.countryName)
                                .tag(jurisdiction.countryCode)
                        }
                    }
                }

                Section {
                    Picker("Currency", selection: $draft.currencyCode) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text("\(currency.rawValue) • \(currency.displayName)")
                                .tag(currency)
                        }
                    }

                    TextField("FX Fee %", text: $draft.foreignTransactionFeePercentText)
                        .focused($focusedField, equals: .foreignTransactionFee)
                        .keyboardType(.decimalPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Currency & FX")
                }

                amountsSection
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        dismiss()
                    }
                    .accessibilityHint("Dismisses account entry without saving.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusedField = nil
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.canSave)
                    .accessibilityHint(
                        draft.canSave
                            ? "Saves this account to your profile."
                            : "Enter account name and institution to save this account."
                    )
                }
            }
            .keyboardDone($focusedField)
            .onChange(of: draft.accountType) { _, newType in
                // If the user switches to a non-credit-card type while
                // a credit-card-only field is focused, clear focus so a
                // now-hidden field never retains the keyboard.
                if !newType.isCreditCard {
                    if focusedField == .creditLimit || focusedField == .availableCredit {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                if draft.jurisdictionCode.isEmpty,
                   let firstJurisdiction = jurisdictions.first
                {
                    draft.jurisdictionCode = firstJurisdiction.countryCode
                    if let currency = firstJurisdiction.currencyCode {
                        draft.currencyCode = currency
                    }
                }

                focusedField = .name
            }
            .onChange(of: draft.jurisdictionCode) { _, jurisdictionCode in
                guard let jurisdiction = jurisdictions.first(where: { $0.countryCode == jurisdictionCode }),
                      let currency = jurisdiction.currencyCode
                else {
                    return
                }

                draft.currencyCode = currency
            }
        }
    }
}

// MARK: - Amount section

private extension SettingsAddAccountSheet {

    @ViewBuilder
    var amountsSection: some View {
        if draft.accountType.isCreditCard {
            creditCardAmountsSection
        } else {
            depositAmountsSection
        }
    }

    var creditCardAmountsSection: some View {
        Section {
            TextField("Credit limit", text: $draft.creditLimitText)
                .focused($focusedField, equals: .creditLimit)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()

            TextField("Current balance (optional)", text: $draft.currentBalanceText)
                .focused($focusedField, equals: .currentBalance)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()

            TextField("Available credit (optional)", text: $draft.availableCreditText)
                .focused($focusedField, equals: .availableCredit)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Credit Card Amounts")
        } footer: {
            Text("A credit limit is capacity, not a balance. Current balance and available credit are optional snapshots from your issuer app — they will be timestamped and flagged when stale.")
        }
    }

    var depositAmountsSection: some View {
        Section {
            TextField("Current balance (optional)", text: $draft.currentBalanceText)
                .focused($focusedField, equals: .currentBalance)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled()
        } header: {
            Text("Latest Balance")
        } footer: {
            Text("Optional. If you enter a balance, NomadFi timestamps it as a snapshot and marks it stale over time. You can update it later in Settings.")
        }
    }
}

/// Temporary form state for creating a new settings account.
struct SettingsAccountDraft: Sendable {
    var name = ""
    var institutionName = ""
    var accountType: AccountType = .checking
    var currencyCode: CurrencyCode = .usd
    var jurisdictionCode = ""
    var currentBalanceText = ""
    var creditLimitText = ""
    var availableCreditText = ""
    var foreignTransactionFeePercentText = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Parses a user-entered decimal string into an optional value. A
    /// blank field stays optional — credit limit / current balance are
    /// intentionally nullable. Negative or malformed inputs clamp to
    /// `nil` so downstream code never has to guess.
    private static func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value >= 0 else {
            return nil
        }
        return value
    }

    var parsedCurrentBalance: Double? {
        Self.parseOptional(currentBalanceText)
    }

    var parsedCreditLimit: Double? {
        Self.parseOptional(creditLimitText)
    }

    var parsedAvailableCredit: Double? {
        Self.parseOptional(availableCreditText)
    }

    var parsedForeignTransactionFeePercent: Double {
        let parsedValue = Double(foreignTransactionFeePercentText) ?? 0
        return max(0, parsedValue)
    }

    /// Whether any user-confirmed snapshot value was supplied. Used by
    /// the persistence bridge to decide whether to stamp a snapshot
    /// timestamp.
    var hasSnapshotValue: Bool {
        if accountType.isCreditCard {
            return parsedCurrentBalance != nil
                || parsedAvailableCredit != nil
        }
        return parsedCurrentBalance != nil
    }
}
