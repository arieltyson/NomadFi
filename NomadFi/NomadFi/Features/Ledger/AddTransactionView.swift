import SwiftData
import SwiftUI

/// A form for manually entering a new transaction.
///
/// Supports cross-border transactions by allowing separate original
/// and home currency amounts, auto-calculating the exchange rate.
struct AddTransactionView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \JurisdictionProfile.displayOrder) private var jurisdictions: [JurisdictionProfile]

    @State private var formData = TransactionFormData()
    @State private var saveCount = 0
    @FocusState private var focusedField: FormField?

    var body: some View {
        NavigationStack {
            Form {
                merchantSection

                amountSection

                categorySection

                accountSection

                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityHint("Dismisses transaction entry without saving.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTransaction)
                        .disabled(!formData.isValid)
                        .bold()
                        .accessibilityHint(
                            formData.isValid
                                ? "Saves this transaction to your ledger."
                                : "Enter merchant and amount to enable saving."
                        )
                }
            }
            .keyboardDoneAccessory(focused: $focusedField)
            .sensoryFeedback(.success, trigger: saveCount)
        }
        .onAppear { focusedField = .merchant }
    }

    /// Advances focus through the form so hardware/software Return
    /// keys on text fields move through the form in order. The
    /// `.decimalPad` amount field doesn't have a Return key; its
    /// dismiss path is the shared keyboard Done toolbar.
    private func advanceFocus(from field: FormField) {
        switch field {
        case .merchant:
            focusedField = .amount
        case .amount:
            focusedField = formData.isCrossBorder ? .convertedAmount : .notes
        case .convertedAmount:
            focusedField = .notes
        case .notes:
            focusedField = nil
        }
    }
}

// MARK: - Form Data

@MainActor
@Observable
final class TransactionFormData {

    var merchantName: String = ""
    var amount: String = ""
    var originalCurrency: CurrencyCode = .usd
    var convertedAmount: String = ""
    var homeCurrency: CurrencyCode = .usd
    var date: Date = .now
    var category: TransactionCategory = .other
    var jurisdiction: String = ""
    var notes: String = ""
    var isTaxDeductible: Bool = false
    var selectedAccountIndex: Int?

    var isValid: Bool {
        !merchantName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(amount) ?? 0) != 0
    }

    var isCrossBorder: Bool {
        originalCurrency != homeCurrency
    }

    /// Auto-calculates the exchange rate from entered amounts.
    var calculatedRate: Double {
        guard let original = Double(amount), original != 0,
              let converted = Double(convertedAmount), converted != 0
        else { return 0 }
        return abs(converted / original)
    }
}

// MARK: - Form Sections

private enum FormField {
    case merchant, amount, convertedAmount, notes
}

private extension AddTransactionView {

    var merchantSection: some View {
        Section("Merchant") {
            TextField("Merchant Name", text: $formData.merchantName)
                .focused($focusedField, equals: .merchant)
                .textContentType(.organizationName)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { advanceFocus(from: .merchant) }

            DatePicker("Date", selection: $formData.date, displayedComponents: .date)
        }
    }

    var amountSection: some View {
        Section("Amount") {
            HStack {
                TextField("Amount", text: $formData.amount)
                    .focused($focusedField, equals: .amount)
                    .keyboardType(.decimalPad)
                    .textContentType(.none)
                    .autocorrectionDisabled()

                Picker("Currency", selection: $formData.originalCurrency) {
                    ForEach(availableCurrencies) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                .labelsHidden()
            }

            if formData.isCrossBorder {
                HStack {
                    TextField("Converted Amount", text: $formData.convertedAmount)
                        .focused($focusedField, equals: .convertedAmount)
                        .keyboardType(.decimalPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()

                    Text(formData.homeCurrency.rawValue)
                        .foregroundStyle(.secondary)
                }

                if formData.calculatedRate > 0 {
                    HStack {
                        Text("Rate")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(formData.calculatedRate, format: .number.precision(.fractionLength(2...4)))
                    }
                    .font(TypographyTokens.caption)
                }
            }

            Picker("Home Currency", selection: $formData.homeCurrency) {
                ForEach(availableCurrencies) { currency in
                    Text("\(currency.rawValue) (\(currency.displayName))").tag(currency)
                }
            }
        }
    }

    var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $formData.category) {
                ForEach(TransactionCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(category)
                }
            }

            if !jurisdictions.isEmpty {
                Picker("Jurisdiction", selection: $formData.jurisdiction) {
                    Text("None").tag("")

                    ForEach(jurisdictions, id: \.countryCode) { profile in
                        Text(profile.countryName).tag(profile.countryCode)
                    }
                }
            }
        }
    }

    var accountSection: some View {
        Section("Account (Optional)") {
            Picker("Account", selection: $formData.selectedAccountIndex) {
                Text("None").tag(nil as Int?)

                ForEach(accounts.enumerated(), id: \.element.name) { index, account in
                    Text("\(account.name) (\(account.institutionName))")
                        .tag(index as Int?)
                }
            }
        }
    }

    var notesSection: some View {
        Section("Notes") {
            TextField("Notes (optional)", text: $formData.notes, axis: .vertical)
                .focused($focusedField, equals: .notes)
                .lineLimit(3...6)
                .textContentType(.none)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { advanceFocus(from: .notes) }

            Toggle("Tax Deductible", isOn: $formData.isTaxDeductible)
        }
    }

    var availableCurrencies: [CurrencyCode] {
        let fromJurisdictions = jurisdictions.compactMap(\.currencyCode)
        let unique = Array(Set(fromJurisdictions))
        return unique.isEmpty ? CurrencyCode.allCases : unique.sorted { $0.rawValue < $1.rawValue }
    }

    func saveTransaction() {
        guard formData.isValid else { return }

        let rawOriginal = -(abs(Double(formData.amount) ?? 0))
        guard let originalAmount = InputSanitizer.validateAmount(rawOriginal) else { return }

        let rawConverted = formData.isCrossBorder
            ? -(abs(Double(formData.convertedAmount) ?? 0))
            : originalAmount
        let convertedAmount = InputSanitizer.validateAmount(rawConverted) ?? originalAmount

        let sanitizedRate = InputSanitizer.validateExchangeRate(formData.calculatedRate) ?? 0

        // The mid-market rate is set equal to the calculated applied rate
        // only because no live FX source is captured at entry time. Both
        // rates are therefore labeled as user-provided/unverified so the
        // detail screen, insights, and intents do not imply verification.
        let now = Date.now
        let appliedProvenance = SourceProvenance.manuallyEnteredAppliedRate(accessedAt: now)
        let midMarketProvenance = SourceProvenance.manuallyEnteredMidMarketRate(accessedAt: now)

        let transaction = Transaction(
            merchantName: InputSanitizer.sanitizeShortText(formData.merchantName),
            originalAmount: originalAmount,
            originalCurrency: formData.originalCurrency,
            convertedAmount: convertedAmount,
            homeCurrency: formData.homeCurrency,
            appliedExchangeRate: sanitizedRate,
            midMarketRate: sanitizedRate,
            date: formData.date,
            category: formData.category,
            jurisdiction: formData.jurisdiction,
            notes: InputSanitizer.sanitizeLongText(formData.notes),
            isTaxDeductible: formData.isTaxDeductible,
            appliedRateProvenance: appliedProvenance,
            midMarketRateProvenance: midMarketProvenance
        )

        if let accountIndex = formData.selectedAccountIndex,
           accounts.indices.contains(accountIndex)
        {
            transaction.account = accounts[accountIndex]
        }

        modelContext.insert(transaction)
        saveCount += 1
        dismiss()
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [
            Account.self, Transaction.self,
            JurisdictionProfile.self, Currency.self,
            ExchangeRate.self, TaxDocument.self,
            Subscription.self, Budget.self,
        ], inMemory: true)
}
