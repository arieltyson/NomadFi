// TaxEducationRecognitionStrip.swift
// NomadFi
//
// Compact, calm recognition strip at the top of the Learn
// surface. Renders portfolio-wide badges as a horizontally
// scrolling row of chips — understated, no spectacle.
//
// Hidden entirely when the summary is empty so first-time users
// never see a row of grey placeholders.

import SwiftUI

struct TaxEducationRecognitionStrip: View {

    let summary: TaxEducationRecognitionSummary

    var body: some View {
        if summary.portfolioBadges.isEmpty {
            EmptyView()
        } else {
            strip
        }
    }

    private var strip: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text("Recognition")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: SpacingTokens.xSmall) {
                    ForEach(summary.portfolioBadges) { badge in
                        chip(for: badge)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recognition. \(summary.portfolioBadges.count) current badges.")
    }

    private func chip(for badge: TaxEducationRecognitionBadge) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
            Image(systemName: badge.systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                Text(badge.title)
                    .font(TypographyTokens.caption)
                    .bold()
                Text(badge.subtitle)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.xSmall)
        .background(
            ColorTokens.surfaceTertiary,
            in: .rect(cornerRadius: RadiusTokens.small, style: .continuous)
        )
        .frame(maxWidth: 260, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.accessibilityLabel)
    }
}
