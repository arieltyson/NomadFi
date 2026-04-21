import SwiftUI

/// Form sheet for adding an account from Settings after onboarding.
struct SettingsAddAccountSheet: View {

    let jurisdictions: [JurisdictionProfile]
    let onSave: (SettingsAccountDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var draft = SettingsAccountDraft()

    enum Field {
        case name
        case institution
        case balance
        case foreignTransactionFee
    }

    /// Moves focus through the form's text fields so the on-screen
    /// Return key advances through name → institution → balance.
    /// `.decimalPad` fields don't surface a Return key, so the shared
    /// keyboard Done toolbar handles dismissal for them.
    private func advanceFocus(from field: Field) {
        switch field {
        case .name: focusedField = .institution
        case .institution: focusedField = .balance
        case .balance, .foreignTransactionFee: focusedField = nil
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

                Section("Currency & Amounts") {
                    Picker("Currency", selection: $draft.currencyCode) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text("\(currency.rawValue) • \(currency.displayName)")
                                .tag(currency)
                        }
                    }

                    TextField("Current Balance", text: $draft.balanceText)
                        .focused($focusedField, equals: .balance)
                        .keyboardType(.decimalPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()

                    TextField("FX Fee %", text: $draft.foreignTransactionFeePercentText)
                        .focused($focusedField, equals: .foreignTransactionFee)
                        .keyboardType(.decimalPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                }
                // Decimal pad has no Return key — focus progression
                // relies on the shared keyboard Done toolbar below.
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityHint("Dismisses account entry without saving.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            .keyboardDismissToolbar { focusedField = nil }
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

/// Temporary form state for creating a new settings account.
struct SettingsAccountDraft: Sendable {
    var name = ""
    var institutionName = ""
    var accountType: AccountType = .checking
    var currencyCode: CurrencyCode = .usd
    var jurisdictionCode = ""
    var balanceText = ""
    var foreignTransactionFeePercentText = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var parsedBalance: Double {
        Double(balanceText) ?? 0
    }

    var parsedForeignTransactionFeePercent: Double {
        let parsedValue = Double(foreignTransactionFeePercentText) ?? 0
        return max(0, parsedValue)
    }
}
