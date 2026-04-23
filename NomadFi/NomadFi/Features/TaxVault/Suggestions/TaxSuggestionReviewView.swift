// TaxSuggestionReviewView.swift
// NomadFi
//
// Modal review sheet for a single `TaxCategorySuggestion`.
// Deliberately calm + procedural: the user sees the evidence
// NomadFi saw, can edit the proposed category, and confirms or
// dismisses explicitly. No silent writes.
//
// Honest-copy invariants baked into the strings below:
//   • "May be tax-relevant" — never "This is deductible".
//   • "Suggested category" — never "This qualifies".
//   • "Review before including" — never "You can claim this".

import SwiftData
import SwiftUI

struct TaxSuggestionReviewView: View {

    let suggestion: TaxCategorySuggestion
    let transactions: [Transaction]
    @Bindable var viewModel: TaxSuggestionReviewViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var confirmationFeedback: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                signalsSection
                proposalSection
                disclaimerSection
                actionsSection
            }
            .navigationTitle("Review suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: confirmationFeedback)
        }
    }
}

// MARK: - Sections

private extension TaxSuggestionReviewView {

    var headerSection: some View {
        Section {
            LabeledContent("Merchant") {
                Text(suggestion.merchantName)
                    .fontWeight(.semibold)
            }
            LabeledContent("Amount") {
                Text(suggestion.amount, format: .currency(code: suggestion.currencyCode.rawValue))
                    .monospacedDigit()
            }
            LabeledContent("Date") {
                Text(suggestion.transactionDate.formatted(.dateTime.year().month(.wide).day()))
            }
            if !suggestion.jurisdiction.isEmpty {
                LabeledContent("Jurisdiction") {
                    Text(suggestion.jurisdiction)
                }
            }
            if let existing = suggestion.existingTransactionCategory {
                LabeledContent("Existing tag") {
                    Text(existing.displayName)
                }
            }
        } header: {
            Text("Transaction")
        } footer: {
            Text("This transaction may be tax-relevant. Review before including it in your tax records.")
                .font(TypographyTokens.caption)
        }
    }

    var signalsSection: some View {
        Section {
            if suggestion.reasons.isEmpty {
                Text("No specific keyword signals on file.")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestion.reasons) { reason in
                    Label {
                        Text(reason.displayText)
                            .font(TypographyTokens.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundStyle(ColorTokens.brandPrimary)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Why NomadFi surfaced this")
        }
    }

    var proposalSection: some View {
        Section {
            Picker("Suggested category", selection: $viewModel.draftCategory) {
                ForEach(TaxCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            StatusBadge(
                label: suggestion.confidence.displayLabel,
                color: confidenceColor,
                systemImage: suggestion.confidence.systemImage
            )
            .accessibilityLabel(suggestion.confidence.accessibilityLabel)
        } header: {
            Text("Proposal")
        } footer: {
            Text("You can change the suggested category before confirming. NomadFi does not decide deductibility for you.")
                .font(TypographyTokens.caption)
        }
    }

    var disclaimerSection: some View {
        Section {
            Label {
                Text("NomadFi does not provide tax advice. Suggestions are procedural only. Nothing is written to your tax records until you confirm.")
                    .font(TypographyTokens.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(ColorTokens.neutral)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Reminder")
        }
    }

    var actionsSection: some View {
        Section {
            Button {
                confirm()
            } label: {
                Label("Confirm and add to Tax Vault", systemImage: "checkmark.seal")
            }
            .accessibilityHint("Creates a linked tax document with the selected category. NomadFi does not mark the expense deductible automatically.")

            Button(role: .destructive) {
                dismissSuggestion()
            } label: {
                Label("Dismiss suggestion", systemImage: "xmark.circle")
            }
            .accessibilityHint("Removes this row from the review queue. NomadFi never resurfaces dismissed suggestions.")
        }
    }
}

// MARK: - Helpers

private extension TaxSuggestionReviewView {

    var confidenceColor: Color {
        switch suggestion.confidence {
        case .high: ColorTokens.positive
        case .medium: ColorTokens.warning
        case .low: ColorTokens.neutral
        }
    }

    func confirm() {
        let outcome = viewModel.confirm(
            suggestion,
            category: viewModel.draftCategory,
            in: modelContext,
            transactions: transactions
        )
        if outcome != .failed {
            confirmationFeedback &+= 1
        }
        dismiss()
    }

    func dismissSuggestion() {
        viewModel.dismiss(
            suggestion,
            in: modelContext,
            transactions: transactions
        )
        dismiss()
    }
}
