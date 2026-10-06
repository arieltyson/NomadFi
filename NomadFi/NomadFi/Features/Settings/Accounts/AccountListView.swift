// AccountListView.swift
// NomadFi
//
// Settings → Financial Setup → Accounts.

import SwiftData
import SwiftUI

/// Every account on one screen of its own, built for managing many.
///
/// Search hides until pulled down. Edit turns on multi-select, as in
/// Mail: tick any number, then Delete in the bottom bar. Swipe deletes
/// one. Either way a centred alert confirms, because deleting an
/// account also deletes its transactions and subscriptions.
struct AccountListView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var accounts: [Account]

    @Query(sort: \JurisdictionProfile.displayOrder)
    private var jurisdictions: [JurisdictionProfile]

    @State private var viewModel = AccountListViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var isAddingAccount = false

    var body: some View {
        let visible = viewModel.visibleAccounts(accounts)

        List(selection: $viewModel.selection) {
            ForEach(visible) { account in
                NavigationLink {
                    AccountDetailView(account: account)
                } label: {
                    SettingsAccountRow(account: account)
                }
            }
            // Swipe deletes one outside Edit; in Edit, rows only select.
            .onDelete(perform: editMode.isEditing ? nil : { offsets in
                viewModel.requestDeletion(of: offsets.map { visible[$0] })
            })
        }
        .overlay {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "creditcard",
                    description: Text("Tap + to add one.")
                )
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search accounts")
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .disabled(accounts.isEmpty)
            }

            if editMode.isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button(viewModel.isAllSelected(in: visible) ? "Deselect All" : "Select All") {
                        viewModel.toggleSelectAll(in: visible)
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete", role: .destructive) {
                        viewModel.requestDeletionOfSelection(from: visible)
                    }
                    .disabled(viewModel.selection.isEmpty)
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Account", systemImage: "plus") {
                        isAddingAccount = true
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        // Selecting borrows the bottom of the screen, as in Mail.
        .toolbar(editMode.isEditing ? .hidden : .visible, for: .tabBar)
        .destructiveDataLossAlert(
            LocalizedStringKey(viewModel.deletionTitle),
            isPresented: $viewModel.isConfirmingDeletion,
            confirmationLabel: "Delete",
            message: LocalizedStringKey(viewModel.deletionMessage)
        ) {
            viewModel.confirmDeletion(in: modelContext)
            if accounts.isEmpty {
                editMode = .inactive
            }
        }
        .onChange(of: editMode) { _, mode in
            if !mode.isEditing {
                viewModel.selection = []
            }
        }
        .sheet(isPresented: $isAddingAccount) {
            SettingsAddAccountSheet(jurisdictions: jurisdictions) { draft in
                viewModel.add(draft, to: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountListView()
    }
    .modelContainer(for: [Account.self, JurisdictionProfile.self], inMemory: true)
}
