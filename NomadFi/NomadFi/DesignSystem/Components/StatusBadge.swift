// StatusBadge.swift
// NomadFi
//
// A small badge indicating jurisdiction, FX markup level,
// or budget status with color and icon.

import SwiftUI

/// A compact status indicator badge with icon, label, and semantic color.
///
/// Used throughout the app for jurisdiction flags, FX markup indicators,
/// and budget status chips.
///
/// ```swift
/// StatusBadge(label: "US", color: .blue)
/// StatusBadge(label: "Fair Rate", color: ColorTokens.positive, systemImage: "checkmark.circle")
/// ```
struct StatusBadge: View {

    let label: String
    var color: Color = ColorTokens.neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: SpacingTokens.xxSmall) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(label)
                .font(TypographyTokens.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, SpacingTokens.xSmall)
        .padding(.vertical, SpacingTokens.xxSmall)
        .background(color.opacity(0.12))
        .clipShape(.capsule)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: SpacingTokens.small) {
        StatusBadge(label: "US", color: .blue)
        StatusBadge(
            label: "Fair Rate",
            color: ColorTokens.positive,
            systemImage: "checkmark.circle"
        )
        StatusBadge(
            label: "Over Budget",
            color: ColorTokens.negative,
            systemImage: "exclamationmark.triangle"
        )
        StatusBadge(
            label: "2.5% FX Fee",
            color: ColorTokens.warning,
            systemImage: "exclamationmark.circle"
        )
    }
    .padding()
}
