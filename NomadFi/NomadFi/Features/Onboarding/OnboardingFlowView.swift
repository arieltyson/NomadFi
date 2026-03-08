import SwiftData
import SwiftUI

/// The root container for the onboarding flow.
///
/// Manages step transitions with matched geometry animation
/// and persists data to SwiftData on completion.
struct OnboardingFlowView: View {

    @Binding var hasCompletedOnboarding: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(onGetStarted: viewModel.advance)
                    .transition(.push(from: .trailing))

            case .jurisdictions:
                JurisdictionSelectionView(viewModel: viewModel)
                    .transition(.push(from: .trailing))

            case .currency:
                CurrencyConfigurationView(viewModel: viewModel)
                    .transition(.push(from: .trailing))

            case .accounts:
                AccountConnectionView(viewModel: viewModel, onComplete: finishOnboarding)
                    .transition(.push(from: .trailing))
            }
        }
        .reduceMotionAnimation(AnimationTokens.standard, value: viewModel.currentStep)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if viewModel.currentStep != .welcome {
                    Button("Back", systemImage: "chevron.left", action: viewModel.goBack)
                        .accessibilityHint("Returns to the previous onboarding step.")
                }
            }
        }
    }

    private func finishOnboarding() {
        viewModel.completeOnboarding(modelContext: modelContext)
        hasCompletedOnboarding = true
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
