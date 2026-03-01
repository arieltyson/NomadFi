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

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $viewModel.accountName)
                        .focused($focusedField, equals: .name)
                        .textContentType(.organizationName)

                    TextField("Institution", text: $viewModel.accountInstitution)
                        .focused($focusedField, equals: .institution)
                        .textContentType(.organizationName)
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
                }
            }
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addCurrentAccount()
                        isPresented = false
                    }
                    .disabled(!viewModel.canAddAccount)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focusedField = .name }
    }
}

// MARK: - Account Row

private struct AccountRow: View {

    let draft: AccountDraft

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: draft.accountType.systemImage)
                .font(.title3)
                .foregroundStyle(ColorTokens.brandPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(draft.name)
                    .font(TypographyTokens.sectionHeader)

                Text(draft.institutionName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: SpacingTokens.xxSmall) {
                CurrencyText(amount: draft.balance, currencyCode: draft.currencyCode)

                Text(draft.currencyCode.rawValue)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.name) at \(draft.institutionName), balance \(draft.balance.formatted(.currency(code: draft.currencyCode.rawValue))), \(draft.accountType.displayName)")
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

            Button("Finish Setup", action: onComplete)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityHint(
                    viewModel.addedAccounts.isEmpty
                        ? "You can add accounts later from the dashboard"
                        : "Saves your accounts and opens the dashboard"
                )
        }
    }
}

#Preview {
    let viewModel = OnboardingViewModel()
    viewModel.selectedJurisdictions = Array(JurisdictionInfo.supported.prefix(3))
    return AccountConnectionView(viewModel: viewModel, onComplete: { })
}
