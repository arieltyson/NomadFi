import SwiftUI

/// A subcategory row that opens to show the merchants inside it, largest
/// first. Long lists show the first few until the person asks for all.
struct SpendingSubcategorySection: View {

    let slice: SpendingChartSlice
    let subcategory: SpendingSubcategorySlice
    let currency: CurrencyCode
    let choices: [SpendingSubcategory]
    let isHighlighted: Bool
    @Binding var isExpanded: Bool
    let onAssign: (_ merchantKey: String, _ subcategoryID: String?) -> Void

    /// How many merchants show before "Show All".
    static let collapsedMerchantCount = 5

    @State private var showsAllMerchants = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            Button {
                withAnimation(reduceMotion ? nil : AnimationTokens.standard) {
                    isExpanded.toggle()
                }
            } label: {
                SpendingSliceRow(
                    slice: slice,
                    currency: currency,
                    accessory: .expands(isExpanded: isExpanded),
                    isHighlighted: isHighlighted
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides its merchants." : "Shows its merchants.")
            .accessibilityAddTraits(isExpanded ? [.isHeader] : [])

            if isExpanded {
                let merchants = showsAllMerchants
                    ? subcategory.merchants
                    : Array(subcategory.merchants.prefix(Self.collapsedMerchantCount))
                ForEach(merchants) { merchant in
                    SpendingMerchantRow(merchant: merchant, currency: currency, choices: choices) { subcategoryID in
                        onAssign(merchant.id, subcategoryID)
                    }
                }
                if subcategory.merchants.count > Self.collapsedMerchantCount {
                    Button(showsAllMerchants ? "Show Less" : "Show All \(subcategory.merchants.count)") {
                        withAnimation(reduceMotion ? nil : AnimationTokens.standard) {
                            showsAllMerchants.toggle()
                        }
                    }
                    .font(TypographyTokens.footnote)
                    .padding(.leading, SpacingTokens.xxLarge)
                    .padding(.vertical, SpacingTokens.xSmall)
                }
            }
        }
    }
}
