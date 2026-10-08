import SwiftUI

/// Resolves an onboarding navigation destination to its screen.
struct OnboardingStepView: View {

    let step: OnboardingViewModel.Step
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        switch step {
        case .jurisdictions:
            JurisdictionSelectionView(viewModel: viewModel)
        case .currency:
            CurrencyConfigurationView(viewModel: viewModel)
        case .accounts:
            AccountConnectionView(viewModel: viewModel, onComplete: onComplete)
        }
    }
}
