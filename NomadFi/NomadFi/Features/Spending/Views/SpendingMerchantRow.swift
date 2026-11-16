import SwiftUI

/// One merchant within a subcategory. Tapping it opens a short menu to
/// say what kind of spending it is, which applies to every purchase there.
struct SpendingMerchantRow: View {

    let merchant: SpendingMerchantSlice
    let currency: CurrencyCode
    /// The kinds this merchant's category splits into.
    let choices: [SpendingSubcategory]
    let onAssign: (_ subcategoryID: String?) -> Void

    var body: some View {
        Menu {
            Picker("Count As", selection: Binding(
                get: { merchant.ruledSubcategoryID },
                set: { onAssign($0) }
            )) {
                Label("Automatic", systemImage: "wand.and.sparkles")
                    .tag(String?.none)
                ForEach(choices) { choice in
                    Label(choice.name, systemImage: choice.systemImage)
                        .tag(Optional(choice.id))
                }
            }
        } label: {
            HStack(spacing: SpacingTokens.small) {
                VStack(alignment: .leading, spacing: SpacingTokens.xxxSmall) {
                    Text(merchant.name)
                        .font(TypographyTokens.body)
                        .lineLimit(2)
                    Text("^[\(merchant.purchaseCount) purchase](inflect: true)")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: SpacingTokens.xSmall)
                CurrencyText(amount: merchant.total, currencyCode: currency)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, SpacingTokens.xSmall)
            .padding(.leading, SpacingTokens.xxLarge)
            .padding(.trailing, SpacingTokens.xSmall)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Choose what kind of spending this merchant is.")
    }
}
