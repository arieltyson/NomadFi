// AccountDetailView.swift
// NomadFi
//
// Native Form-based editor for a persisted `Account`. Lets the user
// correct mis-entered data (e.g. moving a credit limit out of the
// legacy balance field) and keeps live amounts timestamped as honest
// snapshots. The credit-card-terms section only appears for credit
// cards.

import SwiftData
import SwiftUI

/// Editor for a persisted account's profile, credit terms, and latest
/// snapshot. Pushed onto the Settings navigation stack when the user
/// taps an account row.
struct AccountDetailView: View {

    @Bindable var account: Account

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JurisdictionProfile.displayOrder) private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel: AccountDetailViewModel?
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name
        case institution
        case creditLimit
        case availableCredit
        case currentBalance
        case statementBalance
        case foreignTransactionFee
    }

    var body: some View {
        Group {
            if let viewModel {
                Form {
                    profileSection(viewModel: viewModel)

                    if viewModel.isCreditCard {
                        creditCardTermsSection(viewModel: viewModel)
                        if viewModel.canMoveLegacyBalanceIntoLimit {
                            legacyBalanceMigrationSection(viewModel: viewModel)
                        }
                    }

                    latestSnapshotSection(viewModel: viewModel)

                    if viewModel.isCreditCard {
                        statementCalendarLinkSection
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ProgressView()
                    .task { viewModel = AccountDetailViewModel(account: account) }
            }
        }
        .navigationTitle(account.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    focusedField = nil
                    viewModel?.save()
                    dismiss()
                }
                .disabled(viewModel?.canSave != true)
                .accessibilityHint("Saves your changes to this account and returns to Settings.")
            }

            KeyboardDismissToolbarItem { focusedField = nil }
        }
        .onChange(of: viewModel?.accountType) { _, newType in
            // Guard against focus lingering on a field that disappears
            // when the user switches away from Credit Card.
            guard let newType, !newType.isCreditCard else { return }
            if focusedField == .creditLimit
                || focusedField == .availableCredit
                || focusedField == .statementBalance
            {
                focusedField = nil
            }
        }
    }
}

// MARK: - Sections

private extension AccountDetailView {

    func profileSection(viewModel: AccountDetailViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return Section {
            TextField("Account Name", text: $viewModel.name)
                .focused($focusedField, equals: .name)
                .textContentType(.organizationName)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focusedField = .institution }

            TextField("Institution", text: $viewModel.institutionName)
                .focused($focusedField, equals: .institution)
                .textContentType(.organizationName)
                .autocorrectionDisabled()

            Picker("Account Type", selection: $viewModel.accountType) {
                ForEach(AccountType.allCases) { type in
                    Label(type.displayName, systemImage: type.systemImage).tag(type)
                }
            }

            Picker("Currency", selection: $viewModel.currencyCode) {
                ForEach(CurrencyCode.allCases) { currency in
                    Text("\(currency.rawValue) • \(currency.displayName)").tag(currency)
                }
            }

            Picker("Jurisdiction", selection: $viewModel.jurisdictionCode) {
                Text("None").tag("")
                ForEach(jurisdictions) { jurisdiction in
                    Text(jurisdiction.countryName).tag(jurisdiction.countryCode)
                }
            }

            TextField("FX Fee %", text: $viewModel.foreignTransactionFeePercentText)
                .focused($focusedField, equals: .foreignTransactionFee)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()
        } header: {
            Text("Profile")
        }
    }

    func creditCardTermsSection(viewModel: AccountDetailViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return Section {
            TextField("Credit limit", text: $viewModel.creditLimitText)
                .focused($focusedField, equals: .creditLimit)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()

            TextField("Available credit (optional)", text: $viewModel.availableCreditText)
                .focused($focusedField, equals: .availableCredit)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()
        } header: {
            Text("Credit Card Terms")
        } footer: {
            Text("A credit limit is capacity, not a balance. NomadFi never counts it toward your net worth.")
        }
    }

    func legacyBalanceMigrationSection(viewModel: AccountDetailViewModel) -> some View {
        Section {
            Button("Move \(account.balance.formatted(.currency(code: account.currencyCodeRawValue))) into credit limit", systemImage: "arrow.turn.up.right") {
                viewModel.moveLegacyBalanceIntoLimit()
            }
            .accessibilityHint("Credit limits are not balances. This moves the value you previously entered into the credit limit field.")
        } header: {
            Text("Fix Mis-Entered Data")
        } footer: {
            Text("This account has a legacy balance but no credit limit. If the number above is actually your credit limit, move it here — a limit is capacity, not a balance.")
        }
    }

    func latestSnapshotSection(viewModel: AccountDetailViewModel) -> some View {
        @Bindable var viewModel = viewModel

        return Section {
            if viewModel.isCreditCard {
                TextField("Current balance (amount owed)", text: $viewModel.currentBalanceText)
                    .focused($focusedField, equals: .currentBalance)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()

                TextField("Statement balance (optional)", text: $viewModel.statementBalanceText)
                    .focused($focusedField, equals: .statementBalance)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
            } else {
                TextField("Current balance", text: $viewModel.currentBalanceText)
                    .focused($focusedField, equals: .currentBalance)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
            }

            if let updatedAt = viewModel.snapshotLastUpdatedAt {
                LabeledContent("Last updated") {
                    Text(updatedAt, format: .dateTime.year().month(.wide).day().hour().minute())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }

            LabeledContent("Source") {
                Text(viewModel.snapshotSource.displayName)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if viewModel.snapshotLastUpdatedAt != nil {
                Button("Clear snapshot", role: .destructive) {
                    viewModel.clearSnapshot()
                }
                .accessibilityHint("Removes the saved balance snapshot. Your account profile stays intact.")
            }
        } header: {
            Text("Latest Snapshot")
        } footer: {
            Text("Snapshots are point-in-time readings. NomadFi timestamps them and flags them as stale over time — it never treats an outdated snapshot as live.")
        }
    }

    var statementCalendarLinkSection: some View {
        Section {
            NavigationLink {
                CreditCardScheduleEditView(account: account)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        Text("Statement Calendar")
                            .font(TypographyTokens.body)
                        Text("Close date, payment due date, and last-confirmed timestamp.")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(ColorTokens.brandPrimary)
                }
            }
        } header: {
            Text("Statement Calendar")
        }
    }
}
