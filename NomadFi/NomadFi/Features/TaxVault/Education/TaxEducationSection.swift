// TaxEducationSection.swift
// NomadFi
//
// "Learn for your jurisdictions" section rendered near the top of
// `TaxVaultView`. One region group per active jurisdiction (home
// first), each containing a compact checklist card followed by
// lesson rows. Tapping a lesson opens the detail sheet via the
// shared view-model.

import SwiftUI

struct TaxEducationSection: View {

    let bundles: [TaxEducationRegionBundle]
    let onSelect: (TaxEducationLesson) -> Void

    var body: some View {
        Section {
            ForEach(bundles) { bundle in
                regionBlock(bundle)
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Label("Learn for your jurisdictions", systemImage: "books.vertical")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(bundles.count)")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } footer: {
            Text("Education only. Not a substitute for a qualified professional. NomadFi does not file on your behalf.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Region block

    private func regionBlock(_ bundle: TaxEducationRegionBundle) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            regionHeader(for: bundle)
            TaxEducationChecklistCard(checklist: bundle.checklist)
            if !bundle.lessons.isEmpty {
                lessonsList(for: bundle)
            }
        }
        .padding(.vertical, SpacingTokens.xxSmall)
    }

    private func regionHeader(for bundle: TaxEducationRegionBundle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.xSmall) {
            Image(systemName: bundle.region.systemImage)
                .foregroundStyle(ColorTokens.brandPrimary)
                .accessibilityHidden(true)
            Text(bundle.region.displayName)
                .font(TypographyTokens.sectionHeader)
            if bundle.isHome {
                StatusBadge(
                    label: "Home",
                    color: ColorTokens.positive,
                    systemImage: "house"
                )
                .accessibilityLabel("Home jurisdiction.")
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func lessonsList(for bundle: TaxEducationRegionBundle) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xSmall) {
            Text("Lessons")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(bundle.lessons) { lesson in
                Button {
                    onSelect(lesson)
                } label: {
                    TaxEducationLessonRow(lesson: lesson)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the full lesson detail.")
            }
        }
    }
}
