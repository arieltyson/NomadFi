// SpokenPurchaseSheet.swift
// NomadFi
//
// Say what you are buying; NomadFi fills in the purchase.

import SwiftUI

/// A small listening sheet: a microphone, the words as they are heard,
/// and one button to use them. Recognition happens on this iPhone.
struct SpokenPurchaseSheet: View {

    let onUse: (PurchaseUtterance) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: SpokenPurchaseViewModel

    init(viewModel: SpokenPurchaseViewModel = SpokenPurchaseViewModel(), onUse: @escaping (PurchaseUtterance) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onUse = onUse
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SpacingTokens.large) {
                Image(systemName: viewModel.error == nil ? "mic.fill" : "mic.slash.fill")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(ColorTokens.brandPrimary.gradient)
                    .symbolEffect(.variableColor.iterative, isActive: viewModel.isListening && !reduceMotion)
                    .accessibilityHidden(true)

                SpokenPurchaseTranscript(transcript: viewModel.transcript, error: viewModel.error)

                Label("Recognised on this iPhone", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(SpacingTokens.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaBar(edge: .bottom) {
                Button("Use This") {
                    onUse(viewModel.utterance)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .buttonSizing(.flexible)
                .disabled(viewModel.utterance.isEmpty)
                .padding(.horizontal, SpacingTokens.large)
                .padding(.bottom, SpacingTokens.medium)
            }
            .navigationTitle("Say It")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task { await viewModel.listen() }
            .onDisappear { Task { await viewModel.stop() } }
        }
        .presentationDetents([.medium])
    }
}

/// The words heard so far, a prompt before any, or why listening failed.
private struct SpokenPurchaseTranscript: View {

    let transcript: String
    let error: SpeechTranscriptionError?

    var body: some View {
        Group {
            if let error {
                Text(message(for: error))
                    .foregroundStyle(.secondary)
            } else if transcript.isEmpty {
                Text("Say what you're buying, like \"forty dollars at Whole Foods\".")
                    .foregroundStyle(.secondary)
            } else {
                Text(transcript)
                    .font(.title3)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func message(for error: SpeechTranscriptionError) -> LocalizedStringKey {
        switch error {
        case .permissionDenied: "Allow Microphone and Speech Recognition for NomadFi in Settings to use Say It."
        case .onDeviceUnavailable: "This iPhone can't recognise speech on device in your language, so NomadFi won't send your voice anywhere. Type the purchase instead."
        case .audioUnavailable: "The microphone couldn't start. Try again in a moment."
        }
    }
}
