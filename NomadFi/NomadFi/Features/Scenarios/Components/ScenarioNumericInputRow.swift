// ScenarioNumericInputRow.swift
// NomadFi
//
// Compact numeric input row used throughout the Scenario Decision Brief
// for entering durable, user-confirmed numeric inputs (Chase available
// credit, Chase current balance, Wise USD balance, etc.). Participates
// in a parent-owned `@FocusState` so the Scenario sheet can present a
// shared keyboard toolbar with a Done button — `.decimalPad` has no
// Return key, so an explicit dismiss affordance is mandatory.

import SwiftUI

/// A single-line labelled numeric input bound to an optional `Double`.
///
/// Generic over a `Hashable` focus value so multiple rows can share one
/// parent `@FocusState<Field?>`; the shared `Field` identifies which
/// row is currently editing.
struct ScenarioNumericInputRow<Field: Hashable>: View {

    let title: String
    let helper: String?
    let placeholder: String
    let systemImage: String
    @Binding var value: Double?

    /// Parent-owned focus binding so the Scenario sheet can clear
    /// focus from its keyboard toolbar's Done button.
    @FocusState.Binding var focusedField: Field?

    /// The focus value this row represents. Taps on the text field
    /// set `focusedField` to this value; the shared Done button
    /// clears it.
    let field: Field

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
                .textFieldStyle(.nomadFi)
                .frame(maxWidth: 140)
                .monospacedDigit()
                .focused($focusedField, equals: field)
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
    PreviewHost()
}

/// Small preview host so `@FocusState` binds to a concrete type and the
/// preview compiles without generics inference hiccups.
private struct PreviewHost: View {

    @State private var value: Double? = nil
    @FocusState private var focusedField: PreviewField?

    var body: some View {
        VStack {
            ScenarioNumericInputRow(
                title: "Chase available credit",
                helper: "From the Chase app — USD",
                placeholder: "USD",
                systemImage: "creditcard",
                value: $value,
                focusedField: $focusedField,
                field: .available
            )
            ScenarioNumericInputRow(
                title: "Wise USD balance",
                helper: "From the Wise app — USD",
                placeholder: "USD",
                systemImage: "wallet.pass.fill",
                value: .constant(500.0),
                focusedField: $focusedField,
                field: .wise
            )
        }
        .padding()
    }
}

private enum PreviewField: Hashable {
    case available
    case wise
}
