// ScenarioNumericInputRow.swift
// NomadFi
//
// Compact numeric input row used throughout the Scenario Decision Brief
// for entering durable, user-confirmed numeric inputs (Chase available
// credit, Chase current balance, Wise USD balance, etc.).

import SwiftUI

/// A single-line labelled numeric input bound to an optional `Double`.
/// The text field uses `.decimalPad` so iOS renders the numeric keyboard
/// and preserves Dynamic Type in the label and helper text.
struct ScenarioNumericInputRow: View {

    let title: String
    let helper: String?
    let placeholder: String
    let systemImage: String
    @Binding var value: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            HStack(spacing: SpacingTokens.xSmall) {
                Image(systemName: systemImage)
                    .foregroundStyle(ColorTokens.brandPrimary)
                    .accessibilityHidden(true)

                Text(title)
                    .font(TypographyTokens.body)

                Spacer(minLength: SpacingTokens.xSmall)

                TextField(
                    placeholder,
                    value: $value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 140)
                .monospacedDigit()
                .accessibilityLabel(title)
            }

            if let helper {
                Text(helper)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    @Previewable @State var value: Double? = nil
    return VStack {
        ScenarioNumericInputRow(
            title: "Chase available credit",
            helper: "From the Chase app — USD",
            placeholder: "USD",
            systemImage: "creditcard",
            value: $value
        )
        ScenarioNumericInputRow(
            title: "Wise USD balance",
            helper: "From the Wise app — USD",
            placeholder: "USD",
            systemImage: "wallet.pass.fill",
            value: .constant(500.0)
        )
    }
    .padding()
}
