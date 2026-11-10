// AskFiBotView.swift
// NomadFi
//
// The FiBot tab: ask a question about your own money, privately.

import SwiftData
import SwiftUI

/// The root of the FiBot tab.
///
/// Before the first question the screen is a single invitation, Ask
/// FiBot, with three starter questions. Afterwards it is a quiet
/// conversation in which every answer carries its own verification.
/// The purchase check and starting over sit in the toolbar, out of the
/// way until wanted.
struct AskFiBotView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: AskFiBotViewModel
    @State private var isShowingPurchaseCheck = false

    init(viewModel: AskFiBotViewModel = AskFiBotViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            if viewModel.hasConversation {
                FiBotConversationView(
                    messages: viewModel.messages,
                    isAnswering: viewModel.isAnswering
                )
            } else {
                AskFiBotWelcomeView(availability: viewModel.availability) { question in
                    viewModel.ask(question, using: factSource)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // Centred while it fits, scrollable when it doesn't (Larger
        // Text); the conversation sits at the bottom and follows new answers.
        .defaultScrollAnchor(viewModel.hasConversation ? .bottom : .center, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .background { AskFiBotBackground() }
        .safeAreaInset(edge: .bottom) {
            AskFiBotComposer(
                text: $viewModel.draft,
                isEnabled: viewModel.availability == .available,
                isAnswering: viewModel.isAnswering,
                canSend: viewModel.canSend,
                onSend: { viewModel.send(using: factSource) },
                onStop: viewModel.stop
            )
        }
        // The welcome's own heading says "Ask FiBot"; the title stays
        // for VoiceOver and the back button but is never drawn twice.
        .navigationTitle("Ask FiBot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbar {
            AskFiBotToolbar(
                hasConversation: viewModel.hasConversation,
                onStartOver: viewModel.startOver,
                onCheckPurchase: { isShowingPurchaseCheck = true }
            )
        }
        .navigationDestination(isPresented: $isShowingPurchaseCheck) {
            FiBotWorkspaceView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshAvailability() }
        }
        .onChange(of: viewModel.messages.last) { _, message in
            announce(message)
        }
    }

    private var factSource: SwiftDataFiBotFactSource {
        SwiftDataFiBotFactSource(modelContext: modelContext)
    }

    /// Reads a new answer aloud for VoiceOver, which would otherwise
    /// stay on the composer.
    private func announce(_ message: FiBotMessage?) {
        let text: String? = switch message?.content {
        case .answer(let answer): answer.text
        case .failure(let error): String(localized: error.message)
        case .question, nil: nil
        }
        guard let text else { return }
        AccessibilityNotification.Announcement(text).post()
    }
}

#Preview("Welcome") {
    NavigationStack {
        AskFiBotView(viewModel: AskFiBotViewModel(answerer: ScriptedFiBotAnswerer(drafts: [
            FiBotAnswerDraft(text: "You've spent CAD 820.40 so far this month.", citedFactIDs: ["F1"]),
        ])))
    }
    .modelContainer(for: [Account.self, Transaction.self, Subscription.self, Budget.self], inMemory: true)
}

#Preview("Unavailable") {
    NavigationStack {
        AskFiBotView(viewModel: AskFiBotViewModel(
            answerer: ScriptedFiBotAnswerer(drafts: [], availability: .appleIntelligenceNotEnabled)
        ))
    }
    .modelContainer(for: [Account.self, Transaction.self, Subscription.self, Budget.self], inMemory: true)
}
