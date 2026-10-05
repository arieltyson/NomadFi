// ScenarioSourcesList.swift
// NomadFi
//
// Renders the "Sources" section on the Scenario Decision Brief. Each
// citation opens the official source page in the system browser. The
// app never fetches or caches the linked content — citations are
// pointers the user can verify themselves.

import SwiftUI

/// A labelled list of official sources the brief cites.
struct ScenarioSourcesList: View {

    let citations: [ScenarioCitation]

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Label("Sources", systemImage: "text.book.closed")
                .font(TypographyTokens.sectionHeader)
                .accessibilityAddTraits(.isHeader)

            Text("Each link opens the official source page in Safari. NomadFi does not fetch or cache these pages — you verify them yourself.")
                .font(TypographyTokens.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(citations) { citation in
                ScenarioSourceRow(citation: citation) {
                    openURL(citation.url)
                }
            }
        }
    }
}

/// Single row in ``ScenarioSourcesList``. Tapping opens the source page.
struct ScenarioSourceRow: View {

    let citation: ScenarioCitation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard {
                HStack(alignment: .top, spacing: SpacingTokens.small) {
                    VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                        HStack(spacing: SpacingTokens.xxSmall) {
                            ScenarioEvidenceBadge(tag: citation.evidence)
                            Text(citation.publisher)
                                .font(TypographyTokens.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(citation.title)
                            .font(TypographyTokens.body)
                            .bold()
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text(citation.summary)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: SpacingTokens.xSmall)

                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(citation.publisher) — \(citation.title)")
        .accessibilityHint("Opens the official source in Safari")
    }
}

#Preview {
    ScrollView {
        ScenarioSourcesList(citations: ScenarioCitationCatalog.scenario1)
            .padding()
    }
}
