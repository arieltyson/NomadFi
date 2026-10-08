import SwiftData
import SwiftUI

/// The root container for the onboarding flow.
///
/// Each step is pushed onto a `NavigationStack`, so the system back
/// button and edge-swipe gesture work throughout. Data is persisted
/// to SwiftData on completion.
struct OnboardingFlowView: View {

    @Binding var hasCompletedOnboarding: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            WelcomeView(onGetStarted: viewModel.advance)
                .toolbarVisibility(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingViewModel.Step.self) { step in
                    OnboardingStepView(step: step, viewModel: viewModel, onComplete: finishOnboarding)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .alert("Couldn't Finish Setup", isPresented: $viewModel.isShowingSaveFailure) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your setup wasn't saved. Please try again.")
        }
    }

    private func finishOnboarding() {
        if viewModel.completeOnboarding(modelContext: modelContext) {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingFlowView(hasCompletedOnboarding: .constant(false))
        .modelContainer(for: [
            Currency.self,
            JurisdictionProfile.self,
            Account.self,
            Transaction.self,
            ExchangeRate.self,
            TaxDocument.self,
            Subscription.self,
            Budget.self,
        ], inMemory: true)
}
