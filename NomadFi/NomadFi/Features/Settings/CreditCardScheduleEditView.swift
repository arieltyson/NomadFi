// CreditCardScheduleEditView.swift
// NomadFi
//
// Editor for a single credit card's statement calendar. Uses native
// Form + DatePicker controls so the experience matches iOS Settings
// conventions and stays fully accessible out of the box.

import SwiftUI

/// Dedicated edit flow for a credit-card account's statement calendar.
///
/// The editor is pushed from ``CreditCardScheduleRow`` via a
/// `NavigationLink`. It surfaces a Toggle + DatePicker pair for each
/// optional date so the user can clear any individual value without
/// losing the others.
struct CreditCardScheduleEditView: View {

    @State private var viewModel: CreditCardScheduleEditViewModel
    @State private var isShowingClearConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(account: Account) {
        _viewModel = State(initialValue: CreditCardScheduleEditViewModel(account: account))
    }

    var body: some View {
        Form {
            summarySection
            CreditCardScheduleDateSection(
                title: "Statement Period Start",
                toggleLabel: "Has start date",
                pickerLabel: "Start date",
                footerText: "The first day of the current billing cycle.",
                isOn: $viewModel.hasStatementPeriodStartDate,
                date: $viewModel.statementPeriodStartWorkingDate
            )
            CreditCardScheduleDateSection(
                title: "Statement Closing Date",
                toggleLabel: "Has closing date",
                pickerLabel: "Closing date",
                footerText: "The day the statement closes and its balance is typically reported to the credit bureaus.",
                isOn: $viewModel.hasStatementClosingDate,
                date: $viewModel.statementClosingWorkingDate
            )
            CreditCardScheduleDateSection(
                title: "Payment Due Date",
                toggleLabel: "Has due date",
                pickerLabel: "Due date",
                footerText: "The day the minimum payment is due for this statement.",
                isOn: $viewModel.hasPaymentDueDate,
                date: $viewModel.paymentDueWorkingDate
            )
            confirmationSection
            clearSection
        }
        .navigationTitle(viewModel.account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.save()
                    dismiss()
                }
                .disabled(!viewModel.canSave)
                .accessibilityHint(
                    viewModel.canSave
                        ? "Saves the credit-card calendar."
                        : "Fix the highlighted date conflict before saving."
                )
            }
        }
        .confirmationDialog(
            "Clear all dates?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Dates", role: .destructive) {
                viewModel.clearAll()
            }
        } message: {
            Text("This removes every statement calendar date from this card. You can re-enter them at any time.")
        }
    }
}

// MARK: - Subviews

private extension CreditCardScheduleEditView {

    var summarySection: some View {
        Section {
            CreditCardScheduleSummaryRow(
                account: viewModel.account,
                schedule: viewModel.pendingSchedule
            )

            if let issue = viewModel.validationIssue {
                Label {
                    Text(issue)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.negative)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ColorTokens.negative)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Validation issue: \(issue)")
            }
        } footer: {
            Text("Paying before statement close can reduce reported utilization, but issuer reporting can vary. Verify dates in your issuer app.")
        }
    }

    var confirmationSection: some View {
        Section {
            Toggle("Mark schedule as confirmed", isOn: $viewModel.isMarkedAsConfirmed)
                .accessibilityHint("Indicates you verified these dates against your issuer app.")

            if let lastConfirmed = viewModel.account.statementScheduleLastConfirmedAt,
               viewModel.isMarkedAsConfirmed
            {
                LabeledContent("Last confirmed") {
                    Text(lastConfirmed, format: .dateTime.year().month().day())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last confirmed \(lastConfirmed.formatted(.dateTime.year().month(.wide).day()))")
            }

            Button("Mark Confirmed Today", systemImage: "checkmark.seal") {
                viewModel.markConfirmedNow()
            }
            .accessibilityHint("Stamps today's date as the last time you verified this schedule.")
        } header: {
            Text("Confirmation")
        } footer: {
            Text("The confirmation stamp is informational only. NomadFi does not contact your issuer.")
        }
    }

    var clearSection: some View {
        Section {
            Button("Clear All Dates", systemImage: "trash", role: .destructive) {
                isShowingClearConfirmation = true
            }
            .accessibilityHint("Removes every statement calendar date from this card.")
        }
    }
}

// MARK: - Reusable date section

/// A Toggle + DatePicker pair rendered as its own `Section`. The
/// toggle represents whether the date is set at all — turning it off
/// clears the persisted value on save without losing the working date.
struct CreditCardScheduleDateSection: View {

    let title: String
    let toggleLabel: String
    let pickerLabel: String
    let footerText: String
    @Binding var isOn: Bool
    @Binding var date: Date

    var body: some View {
        Section {
            Toggle(toggleLabel, isOn: $isOn)
            if isOn {
                DatePicker(
                    pickerLabel,
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .accessibilityLabel(pickerLabel)
            }
        } header: {
            Text(title)
        } footer: {
            Text(footerText)
        }
    }
}

// MARK: - Summary row

/// Compact summary shown at the top of the editor. Mirrors
/// ``CreditCardScheduleRow`` without the trailing chevron so the user
/// can see the pending state while they edit.
struct CreditCardScheduleSummaryRow: View {

    let account: Account
    let schedule: CreditCardSchedule

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(account.name)
                    .font(TypographyTokens.body)
                    .bold()

                Text(account.institutionName)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)

                CreditCardScheduleDatePair(schedule: schedule)

                StatusBadge(
                    label: schedule.state.displayLabel,
                    color: CreditCardScheduleRow.color(for: schedule.state),
                    systemImage: schedule.state.systemImage
                )
            }
        } icon: {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            CreditCardScheduleRow.accessibilityLabel(
                for: account,
                schedule: schedule
            )
        )
    }
}

#Preview {
    NavigationStack {
        CreditCardScheduleEditView(
            account: Account(
                name: "Sample Rewards",
                institutionName: "Example Credit Union",
                accountType: .creditCard,
                currencyCode: .usd,
                jurisdiction: "US"
            )
        )
    }
}
