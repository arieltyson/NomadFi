// TransactionImportView.swift
// NomadFi
//
// CSV transaction import flow. Lives under Settings → Advanced
// Tools (Ledger section) so it stays a power-user surface and
// doesn't pull the app back toward being ledger-first.
//
// Every step is explicit:
//   1. Pick an account.
//   2. Choose a CSV file via `fileImporter`.
//   3. Review the parsed preview — counts + per-row list.
//   4. Confirm the import.
//
// No auto-writes on file selection. Privacy copy is always visible:
// the file is processed locally and never uploaded.

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Top-level view for the CSV transaction import flow.
struct TransactionImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var allTransactions: [Transaction]

    @State private var viewModel = TransactionImportViewModel()
    @State private var isShowingFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                introSection
                accountSection

                switch viewModel.phase {
                case .selectingFile:
                    chooseFileSection
                case .parsing:
                    parsingSection
                case .preview(let snapshot):
                    previewSections(for: snapshot)
                case .committed(let result):
                    commitResultSection(result)
                case .error(let message):
                    errorSection(message: message)
                }
            }
            .navigationTitle("Transaction Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [
                .commaSeparatedText,
                UTType(filenameExtension: "tsv") ?? .plainText,
                .plainText,
            ],
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult
        )
    }
}

// MARK: - Sections

private extension TransactionImportView {

    var introSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text("Import a CSV statement")
                        .font(TypographyTokens.body)
                        .bold()
                    Text("NomadFi parses the file on this device and previews the rows before writing anything. Nothing leaves your iPhone.")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "tablecells.badge.ellipsis")
                    .foregroundStyle(ColorTokens.brandPrimary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    var accountSection: some View {
        Section {
            Picker(
                "Account",
                selection: Binding(
                    get: { viewModel.selectedAccount },
                    set: {
                        viewModel.selectedAccount = $0
                        if let currency = $0?.currencyCode {
                            viewModel.homeCurrency = currency
                        }
                    }
                )
            ) {
                Text("Select an account").tag(nil as Account?)
                ForEach(accounts) { account in
                    Text(accountLabel(for: account))
                        .tag(Optional(account))
                }
            }

            Picker(
                "Home currency",
                selection: $viewModel.homeCurrency
            ) {
                ForEach(CurrencyCode.allCases) { code in
                    Text(code.rawValue).tag(code)
                }
            }
        } header: {
            Text("Target account")
        } footer: {
            Text("Imported rows attach to this account. Cross-currency rows import with an unverified exchange rate until you confirm one manually.")
        }
    }

    var chooseFileSection: some View {
        Section {
            Button("Choose CSV File…", systemImage: "doc.badge.plus") {
                isShowingFilePicker = true
            }
            .disabled(viewModel.selectedAccount == nil)
            .accessibilityHint(
                viewModel.selectedAccount == nil
                    ? "Pick an account first."
                    : "Opens the file picker. Parsing happens on this device only."
            )
        } footer: {
            Text("Supports .csv and .tsv exports from Chase-like, CIBC-like, Amex Canada-like, and Wise-like statements, plus a generic fallback. NomadFi never claims official bank integration.")
        }
    }

    var parsingSection: some View {
        Section {
            HStack(spacing: SpacingTokens.small) {
                ProgressView()
                Text("Parsing rows…")
                    .font(TypographyTokens.body)
            }
        }
    }

    @ViewBuilder
    func previewSections(for snapshot: TransactionImportPreviewSnapshot) -> some View {
        Section {
            Label(snapshot.sourceDisplayName, systemImage: "doc.text")
                .accessibilityElement(children: .combine)
            LabeledContent("New") {
                Text("\(snapshot.counts.new)")
                    .monospacedDigit()
            }
            LabeledContent("Duplicate") {
                Text("\(snapshot.counts.duplicate)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Skipped") {
                Text("\(snapshot.counts.skipped)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Preview")
        } footer: {
            Text("Duplicate rows match an existing transaction by external ID or by merchant + amount + date within a few days. Skipped rows show the reason below.")
        }

        Section {
            ForEach(snapshot.rows) { row in
                TransactionImportPreviewRowView(row: row)
            }
        } header: {
            Text("Rows")
        }

        Section {
            Button("Confirm Import", systemImage: "checkmark.circle.fill") {
                viewModel.commit(into: modelContext)
            }
            .disabled(snapshot.counts.new == 0)
            .accessibilityHint(
                snapshot.counts.new == 0
                    ? "No new rows to import — choose a different file."
                    : "Writes the new rows to your ledger. Duplicates and skipped rows are not saved."
            )

            Button("Choose a Different File") {
                viewModel.reset()
            }
        }
    }

    func commitResultSection(_ result: TransactionImportCommitResult) -> some View {
        Section {
            LabeledContent("Imported") {
                Text("\(result.inserted)").monospacedDigit()
            }
            LabeledContent("Duplicates skipped") {
                Text("\(result.skippedDuplicates)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Rows skipped with errors") {
                Text("\(result.skippedInvalid)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Button("Import Another File") {
                viewModel.reset()
            }
        } header: {
            Text("Import complete")
        } footer: {
            Text("Review the new rows in the Ledger. You can edit category or merchant on any row after import.")
        }
    }

    func errorSection(message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(ColorTokens.negative)
                .accessibilityLabel("Error: \(message)")

            Button("Try Again") {
                viewModel.reset()
            }
        }
    }

    // MARK: - Handlers

    func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let first = urls.first else {
                return
            }
            viewModel.loadFile(
                at: first,
                existingTransactions: allTransactions
            )
        case .failure:
            viewModel.reset()
        }
    }

    func accountLabel(for account: Account) -> String {
        let pieces = [
            account.name,
            account.institutionName,
            account.currencyCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        return pieces.joined(separator: " · ")
    }
}

// MARK: - Per-row preview

/// Compact per-row cell shown inside the preview list.
private struct TransactionImportPreviewRowView: View {

    let row: TransactionImportPreviewRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.small) {
            statusIcon

            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                headerText
                    .font(TypographyTokens.body)

                subtitleText
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: SpacingTokens.small)

            amountText
                .font(TypographyTokens.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: some View {
        switch row {
        case .new:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(ColorTokens.positive)
                .accessibilityHidden(true)
        case .duplicate:
            Image(systemName: "arrow.triangle.2.circlepath.circle")
                .foregroundStyle(ColorTokens.warning)
                .accessibilityHidden(true)
        case .skipped:
            Image(systemName: "xmark.circle")
                .foregroundStyle(ColorTokens.negative)
                .accessibilityHidden(true)
        }
    }

    private var headerText: Text {
        switch row {
        case .new(let parsed):
            return Text(parsed.rawMerchantName)
        case .duplicate(let parsed, _):
            return Text(parsed.rawMerchantName)
        case .skipped(let lineNumber, _, _):
            return Text("Line \(lineNumber)")
        }
    }

    private var subtitleText: Text {
        switch row {
        case .new(let parsed):
            return Text("\(parsed.inferredCategory.displayName) · \(parsed.date.formatted(.dateTime.year().month(.abbreviated).day()))")
        case .duplicate(_, let reason):
            return Text(reason)
        case .skipped(_, _, let error):
            return Text(error.displayLabel)
        }
    }

    private var amountText: Text {
        switch row {
        case .new(let parsed), .duplicate(let parsed, _):
            return Text(parsed.amount.formatted(.currency(code: parsed.currencyCode.rawValue)))
        case .skipped:
            return Text("—")
        }
    }
}

#Preview {
    TransactionImportView()
        .modelContainer(
            for: [
                Account.self,
                Transaction.self,
            ],
            inMemory: true
        )
}
