import CoreLocation
import SwiftUI

/// The final onboarding step where users add their financial accounts.
///
/// Supports manual account entry with name, institution, type, currency,
/// and optional balance. Emphasizes on-device privacy and allows users
/// to skip and add accounts later.
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
        case name, institution, balance
    }

    /// Advances focus so Return keys move through name → institution →
    /// balance; balance uses `.decimalPad` and is dismissed via the
    /// shared keyboard Done toolbar instead.
    private func advanceFocus(from field: Field) {
        switch field {
        case .name: focusedField = .institution
        case .institution: focusedField = .balance
        case .balance: focusedField = nil
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

                Section("Balance (Optional)") {
                    TextField("Current Balance", text: $viewModel.accountBalance)
                        .focused($focusedField, equals: .balance)
                        .keyboardType(.decimalPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .accessibilityHint("Dismisses account entry without adding an account.")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
            .keyboardDismissToolbar { focusedField = nil }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focusedField = .name }
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
        .accessibilityLabel("\(draft.name) at \(draft.institutionName), balance \(draft.balance.formatted(.currency(code: draft.currencyCode.rawValue))), \(draft.accountType.displayName)")
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
            CurrencyText(amount: draft.balance, currencyCode: draft.currencyCode)

            Text(draft.currencyCode.rawValue)
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
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

            Text("Add the bank accounts and cards you use across your jurisdictions. Your data never leaves your iPhone.")
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
            Button("Add Account", systemImage: "plus") {
                isShowingForm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Opens a form to add a bank account or card.")

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
