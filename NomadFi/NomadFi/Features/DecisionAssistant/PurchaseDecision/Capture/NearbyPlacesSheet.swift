// NearbyPlacesSheet.swift
// NomadFi
//
// Pick where you are paying from the places around you.

import SwiftUI

/// A short list of nearby places. Choosing one fills in the purchase.
struct NearbyPlacesSheet: View {

    let onSelect: (NearbyPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NearbyPlacesViewModel

    init(viewModel: NearbyPlacesViewModel = NearbyPlacesViewModel(), onSelect: @escaping (NearbyPlace) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Looking around…")
                case .loaded(let places) where places.isEmpty:
                    ContentUnavailableView(
                        "Nothing Nearby",
                        systemImage: "mappin.slash",
                        description: Text("No places were found close to you. Type the merchant instead.")
                    )
                case .loaded(let places):
                    List {
                        Section {
                            ForEach(places) { place in
                                Button {
                                    onSelect(place)
                                    dismiss()
                                } label: {
                                    NearbyPlaceRow(place: place)
                                }
                                .buttonStyle(.plain)
                            }
                        } footer: {
                            Text("Your location is used once to find these places and isn't saved.")
                        }
                    }
                case .failed(.locationDenied):
                    ContentUnavailableView {
                        Label("Location Is Off", systemImage: "location.slash")
                    } description: {
                        Text("Allow Location for NomadFi to see places near you.")
                    } actions: {
                        if let settings = URL(string: "app-settings:") {
                            Link("Open Settings", destination: settings)
                        }
                    }
                case .failed:
                    ContentUnavailableView {
                        Label("Couldn't Find Places", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your connection and try again.")
                    } actions: {
                        Button("Try Again") { Task { await viewModel.load() } }
                    }
                }
            }
            .navigationTitle("Near Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task { await viewModel.load() }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct NearbyPlaceRow: View {

    let place: NearbyPlace

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(place.name)
                Text(place.category.displayLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: place.category.systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
