// InvestingRegionCard.swift
// NomadFi
//
// One jurisdiction on Investing Learn: flag, name and progress.

import SwiftUI

/// A jurisdiction's card on Investing Learn — flag and name above how
/// far through its starter steps the person is. The whole card opens
/// the region's lessons and checklist.
struct InvestingRegionCard: View {

    let summary: InvestingEducationRegionProgressSummary

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
                HStack(spacing: SpacingTokens.xSmall) {
                    Text(String.flagEmoji(for: summary.region.rawValue))
                        .font(.title2)
                    Text(summary.region.displayName)
                        .font(TypographyTokens.sectionHeader)
                        .foregroundStyle(.primary)
                    Spacer(minLength: SpacingTokens.xSmall)
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                InvestingRegionProgress(summary: summary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// "3 of 9 reviewed", or a check once everything is.
private struct InvestingRegionProgress: View {

    let summary: InvestingEducationRegionProgressSummary

    var body: some View {
        if summary.hasCompletedLessonsAndChecklist {
            Label("All reviewed", systemImage: "checkmark.seal.fill")
                .font(TypographyTokens.caption)
                .foregroundStyle(ColorTokens.positive)
        } else {
            Text("\(summary.totalCompleted) of \(summary.totalTrackable) reviewed")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
        }
    }
}
