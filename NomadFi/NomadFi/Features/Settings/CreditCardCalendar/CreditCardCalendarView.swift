// CreditCardCalendarView.swift
// NomadFi
//
// Settings → Financial Setup → Credit Card Calendar.

import SwiftData
import SwiftUI

/// Every credit card's statement calendar, on a page of its own.
///
/// Built like Accounts: search hides until pulled down, and Edit turns
/// on multi-select with Clear Dates in the bottom bar, confirmed by a
/// centred alert.
struct CreditCardCalendarView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var accounts: [Account]

    @State private var viewModel = CreditCardCalendarViewModel()
    @State private var editMode: EditMode = .inactive

    var body: some View {
        let cards = viewModel.visibleCards(accounts)
        let hasCards = accounts.contains(where: \.isCreditCard)

        List(selection: $viewModel.selection) {
            Section {
                ForEach(cards) { card in
                    NavigationLink {
                        CreditCardScheduleEditView(account: card)
                    } label: {
                        CreditCardScheduleRow(account: card)
                    }
                }
            } footer: {
                if hasCards {
                    Text("Paying before statement close can reduce reported utilization, but issuer reporting can vary. Verify dates in your issuer app.")
                }
            }
        }
        .overlay {
            if !hasCards {
                ContentUnavailableView(
                    "No Credit Cards",
                    systemImage: "creditcard",
                    description: Text("Add a credit card in Accounts to track its statement dates here.")
                )
            } else if cards.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search cards")
        .navigationTitle("Credit Card Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .disabled(!hasCards)
            }

            if editMode.isEditing {
                ToolbarItem(placement: .bottomBar) {
                    Button(viewModel.isAllSelected(in: cards) ? "Deselect All" : "Select All") {
                        viewModel.toggleSelectAll(in: cards)
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Clear Dates", role: .destructive) {
                        viewModel.requestClearOfSelection(from: cards)
                    }
                    .disabled(viewModel.selection.isEmpty)
                }
            }
        }
        .environment(\.editMode, $editMode)
        // Selecting borrows the bottom of the screen, as in Mail.
        .toolbar(editMode.isEditing ? .hidden : .visible, for: .tabBar)
        .destructiveDataLossAlert(
            LocalizedStringKey(viewModel.clearTitle),
            isPresented: $viewModel.isConfirmingClear,
            confirmationLabel: "Clear Dates",
            message: LocalizedStringKey(viewModel.clearMessage)
        ) {
            viewModel.confirmClear(in: modelContext)
            editMode = .inactive
        }
        .onChange(of: editMode) { _, mode in
            if !mode.isEditing {
                viewModel.selection = []
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreditCardCalendarView()
    }
    .modelContainer(for: [Account.self], inMemory: true)
}
