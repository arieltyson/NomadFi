import SwiftUI

/// A card displaying a single financial insight or recommendation.
///
/// Used in the "Your Money This Week" section of the dashboard to surface
/// actionable information about FX waste, arbitrage opportunities,
/// budget warnings, and subscription flags.
struct InsightCardView: View {

    let insight: FinancialInsight

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                insightIcon

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(insight.title)
                        .font(TypographyTokens.sectionHeader)

                    Text(insight.message)
                        .font(TypographyTokens.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.category.accessibilityLabel): \(insight.title). \(insight.message)")
    }
}

// MARK: - Private Helpers

private extension InsightCardView {

    var insightIcon: some View {
        Image(systemName: insight.category.systemImage)
            .font(.title3)
            .foregroundStyle(insight.category.color)
            .frame(width: 32, alignment: .center)
            .accessibilityHidden(true)
    }
}

// MARK: - Financial Insight Model

/// A single actionable financial insight for the dashboard.
struct FinancialInsight: Identifiable, Sendable {

    let id = UUID()
    let title: String
    let message: String
    let category: Category

    enum Category: Sendable {
        case fxWaste
        case arbitrage
        case budget
        case subscription

        var systemImage: String {
            switch self {
            case .fxWaste: "exclamationmark.triangle.fill"
            case .arbitrage: "arrow.triangle.swap"
            case .budget: "chart.bar.fill"
            case .subscription: "arrow.2.squarepath"
            }
        }

        var color: Color {
            switch self {
            case .fxWaste: ColorTokens.negative
            case .arbitrage: ColorTokens.positive
            case .budget: ColorTokens.warning
            case .subscription: ColorTokens.brandPrimary
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .fxWaste: "FX waste alert"
            case .arbitrage: "Arbitrage opportunity"
            case .budget: "Budget warning"
            case .subscription: "Subscription insight"
            }
        }
    }
}

// MARK: - Sample Data

extension FinancialInsight {

    /// Sample insights for Previews and first-run demo data.
    static let samples: [FinancialInsight] = [
        FinancialInsight(
            title: "Hidden FX Fee Detected",
            message: "You spent $47 CAD using your US account. That cost $3.20 in hidden fees. Use your CIBC card in Canada instead.",
            category: .fxWaste
        ),
        FinancialInsight(
            title: "Strong USD Today",
            message: "The USD is strong against TTD. Consider sending money home today to maximize your transfer.",
            category: .arbitrage
        ),
        FinancialInsight(
            title: "Budget Alert",
            message: "You have spent 80% of your San Francisco weekly budget with 3 days remaining.",
            category: .budget
        ),
        FinancialInsight(
            title: "Keep Your Canadian Netflix",
            message: "Your Netflix CA subscription is $16.99 CAD ($12.01 USD). The US price is $15.49. Save $3.48/month by keeping it.",
            category: .subscription
        ),
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: SpacingTokens.small) {
            ForEach(FinancialInsight.samples) { insight in
                InsightCardView(insight: insight)
            }
        }
        .padding()
    }
}
