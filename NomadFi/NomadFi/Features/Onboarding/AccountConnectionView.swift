import CoreLocation
import SwiftUI

/// The final onboarding step where users add their financial accounts.
///
/// Supports manual account entry with name, institution, type, currency,
/// and optional snapshot amounts. Credit cards ask for a credit limit
/// plus optional current balance and available credit — all other types
/// ask for an optional current balance. Balances are always optional at
/// onboarding; the user should not be forced to track every transaction
/// just to describe which accounts they have.
struct AccountConnectionView: View {

    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @State private var isShowingForm = false
    @State private var isShowingLocationPermissionPriming = false

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header

            accountList

            Spacer()

            footer
        }
        .padding(SpacingTokens.large)
        .sheet(isPresented: $isShowingForm) {
            AddAccountSheet(viewModel: viewModel, isPresented: $isShowingForm)
        }
        .fullScreenCover(isPresented: $isShowingLocationPermissionPriming) {
            LocationPermissionPrimingView(
                onFinishSetup: {
                    isShowingLocationPermissionPriming = false
                    onComplete()
                },
                onSkipLocation: {
                    isShowingLocationPermissionPriming = false
                    onComplete()
                }
            )
        }
    }
}

// MARK: - Add Account Sheet

private struct AddAccountSheet: View {

    @Bindable var viewModel: OnboardingViewModel
    @Binding var isPresented: Bool
    @FocusState private var focusedField: Field?

    enum Field {
        case name, institution, currentBalance, creditLimit, availableCredit
    }

    /// Advances focus so Return keys move through name → institution.
    /// Amount fields use `.decimalPad` and are dismissed via the shared
    /// keyboard Done toolbar.
    private func advanceFocus(from field: Field) {
        switch field {
        case .name: focusedField = .institution
        case .institution:
            focusedField = viewModel.accountType.isCreditCard ? .creditLimit : .currentBalance
        default: focusedField = nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $viewModel.accountName)
                        .focused($focusedField, equals: .name)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { advanceFocus(from: .name) }

                    TextField("Institution", text: $viewModel.accountInstitution)
                        .focused($focusedField, equals: .institution)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { advanceFocus(from: .institution) }
                }

                Section("Type & Currency") {
                    Picker("Account Type", selection: $viewModel.accountType) {
                        ForEach(AccountType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    Picker("Currency", selection: $viewModel.accountCurrency) {
                        ForEach(viewModel.availableCurrencies) { currency in
                            Text("\(currency.symbol) \(currency.displayName)")
                                .tag(currency)
                        }
                    }
                }

                amountsSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        focusedField = nil
                        isPresented = false
                    }
                    .accessibilityHint("Dismisses account entry without adding an account.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        focusedField = nil
                        viewModel.addCurrentAccount()
                        isPresented = false
                    }
                    .disabled(!viewModel.canAddAccount)
                    .accessibilityHint(
                        viewModel.canAddAccount
                            ? "Adds this account to your onboarding list."
                            : "Enter at least account name and institution to add this account."
                    )
                }
            }
            .keyboardDoneAccessory(focused: $focusedField)
            .onChange(of: viewModel.accountType) { _, newType in
                // Clear focus if it was parked on a credit-card-only
                // field and the user has since switched to another type.
                if !newType.isCreditCard,
                   focusedField == .creditLimit || focusedField == .availableCredit
                {
                    focusedField = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focusedField = .name }
    }

    @ViewBuilder
    private var amountsSection: some View {
        if viewModel.accountType.isCreditCard {
            Section {
                TextField("Credit limit (optional)", text: $viewModel.accountCreditLimitText)
                    .focused($focusedField, equals: .creditLimit)
                    .keyboardType(.decimalPad)
                    .textContentType(.none)
                    .autocorrectionDisabled()

                TextField("Current balance (optional)", text: $viewModel.accountCurrentBalanceText)
                    .focused($focusedField, equals: .currentBalance)
                    .keyboardType(.decimalPad)
                    .textContentType(.none)
                    .autocorrectionDisabled()

                TextField("Available credit (optional)", text: $viewModel.accountAvailableCreditText)
                    .focused($focusedField, equals: .availableCredit)
                    .keyboardType(.decimalPad)
                    .textContentType(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Card Amounts (Optional)")
            } footer: {
                Text("Credit limit is capacity, not a balance. You can skip all three and add them later from Settings.")
            }
        } else {
            Section {
                TextField("Current balance (optional)", text: $viewModel.accountCurrentBalanceText)
                    .focused($focusedField, equals: .currentBalance)
                    .keyboardType(.decimalPad)
                    .textContentType(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Latest Balance (Optional)")
            } footer: {
                Text("You can skip this and add it later from Settings. Saved balances are timestamped as snapshots.")
            }
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {

    let draft: AccountDraft
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                    HStack(spacing: SpacingTokens.small) {
                        icon
                        accountMetadata
                    }

                    amountMetadata
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: SpacingTokens.small) {
                    icon

                    accountMetadata

                    Spacer()

                    amountMetadata
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    var icon: some View {
        Image(systemName: draft.accountType.systemImage)
            .font(.title3)
            .foregroundStyle(ColorTokens.brandPrimary)
            .frame(width: 32)
    }

    var accountMetadata: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text(draft.name)
                .font(TypographyTokens.sectionHeader)

            Text(draft.institutionName)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    var amountMetadata: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: SpacingTokens.xxSmall) {
            primaryLine

            secondaryLine

            Text(draft.currencyCode.rawValue)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var primaryLine: some View {
        if draft.accountType.isCreditCard {
            if let owed = draft.currentBalance {
                Text("Owed \(owed.formatted(.currency(code: draft.currencyCode.rawValue)))")
                    .font(TypographyTokens.amountSmall)
                    .foregroundStyle(ColorTokens.negative)
            } else {
                Text("Balance not set")
                    .font(TypographyTokens.amountSmall)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        } else if let balance = draft.currentBalance {
            CurrencyText(amount: balance, currencyCode: draft.currencyCode)
        } else {
            Text("Balance not set")
                .font(TypographyTokens.amountSmall)
                .italic()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if draft.accountType.isCreditCard, let limit = draft.creditLimit {
            Text("Limit \(limit.formatted(.currency(code: draft.currencyCode.rawValue)))")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(draft.accountType.displayName)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = [draft.name, draft.institutionName, draft.accountType.displayName]
        let code = draft.currencyCode.rawValue

        if draft.accountType.isCreditCard {
            if let limit = draft.creditLimit {
                parts.append("credit limit \(limit.formatted(.currency(code: code)))")
            }
            if let owed = draft.currentBalance {
                parts.append("current balance \(owed.formatted(.currency(code: code)))")
            } else {
                parts.append("balance not set")
            }
        } else if let balance = draft.currentBalance {
            parts.append("current balance \(balance.formatted(.currency(code: code)))")
        } else {
            parts.append("balance not set")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Private Helpers

private extension AccountConnectionView {

    var header: some View {
        VStack(spacing: SpacingTokens.xSmall) {
            Text("Add your accounts")
                .font(TypographyTokens.amountMedium)
                .bold()
                .multilineTextAlignment(.center)

            Text("Add the bank accounts and cards you use across your jurisdictions. Balances are optional — you can always add them later.")
                .font(TypographyTokens.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Label("All data stays on-device", systemImage: "lock.shield")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.brandPrimary)
                .padding(.top, SpacingTokens.xxSmall)
        }
    }

    var accountList: some View {
        Group {
            if viewModel.addedAccounts.isEmpty {
                ContentUnavailableView {
                    Label("No Accounts Yet", systemImage: "creditcard")
                } description: {
                    Text("Tap the button below to add your first account.")
                }
            } else {
                List {
                    ForEach(viewModel.addedAccounts) { draft in
                        AccountRow(draft: draft)
                    }
                    .onDelete(perform: viewModel.removeAccount)
                }
                .listStyle(.plain)
            }
        }
    }

    var footer: some View {
        VStack(spacing: SpacingTokens.small) {
            NomadFiActionButton(
                title: "Add Account",
                systemImage: "plus",
                style: .secondary,
                controlSize: .large,
                accessibilityHint: "Opens a form to add a bank account or card.",
                action: { isShowingForm = true }
            )

            Button("Finish Setup", action: handleFinishSetup)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint(
                    viewModel.addedAccounts.isEmpty
                        ? "You can add accounts later from the dashboard"
                        : "Saves your accounts and opens the dashboard"
                )
        }
    }

    var shouldBypassLocationPriming: Bool {
        ProcessInfo.processInfo.environment["UI_TEST_MODE"] == "1"
    }

    var shouldPresentLocationPriming: Bool {
        guard !shouldBypassLocationPriming else { return false }
        return CLLocationManager().authorizationStatus == .notDetermined
    }

    func handleFinishSetup() {
        if shouldPresentLocationPriming {
            isShowingLocationPermissionPriming = true
        } else {
            onComplete()
        }
    }
}

#Preview {
    let viewModel = OnboardingViewModel()
    viewModel.selectedJurisdictions = Array(JurisdictionInfo.supported.prefix(3))
    return AccountConnectionView(viewModel: viewModel, onComplete: { })
}
