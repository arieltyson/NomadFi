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

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $draft.name)
                        .focused($focusedField, equals: .name)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()

                    TextField("Institution", text: $draft.institutionName)
                        .focused($focusedField, equals: .institution)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
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
                            Text("\(currency.symbol) \(currency.displayName)")
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
            }
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
