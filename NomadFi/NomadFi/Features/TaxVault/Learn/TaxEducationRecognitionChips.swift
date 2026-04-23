// TaxEducationRecognitionChips.swift
// NomadFi
//
// Per-region recognition chips rendered inside each Learn region
// block. Calm + compact — the chips speak to "what you've earned
// for this jurisdiction" at a glance, without turning the block
// into a trophy wall.

import SwiftUI

struct TaxEducationRecognitionChips: View {

    let badges: [TaxEducationRecognitionBadge]

    var body: some View {
        if badges.isEmpty {
            EmptyView()
        } else {
            chipRow
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: SpacingTokens.xSmall) {
                ForEach(badges) { badge in
                    StatusBadge(
                        label: badge.title,
                        color: ColorTokens.positive,
                        systemImage: badge.systemImage
                    )
                    .accessibilityLabel(badge.accessibilityLabel)
                }
            }
            .padding(.vertical, SpacingTokens.xxSmall)
        }
        .scrollIndicators(.hidden)
    }
}
