// SettingsNavigationRow.swift
// NomadFi
//
// A consistent, Apple-Settings-style row that pushes a focused
// subpage. The Settings hub composes these rows so the root screen
// stays short, scannable, and visually calm.

import SwiftUI

/// A `NavigationLink` row styled like Apple's Settings hub:
/// tinted rounded-square icon badge, title, one-line subtitle, an
/// optional right-aligned value accessory ("On" / "Off"), and a
/// native chevron.
///
/// Keeps copy deliberately short — the detail page is where full
/// descriptions live. Destructive rows should use a dedicated
/// `Button`, never this navigation row.
struct SettingsNavigationRow<Destination: View>: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let systemImage: String
    let tint: Color
    let accessory: LocalizedStringKey?
    let accessibilityStatus: LocalizedStringKey?
    @ViewBuilder var destination: () -> Destination

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = ColorTokens.brandPrimary,
        accessory: LocalizedStringKey? = nil,
        accessibilityStatus: LocalizedStringKey? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.accessory = accessory
        self.accessibilityStatus = accessibilityStatus
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: SpacingTokens.small) {
                TintedIconBadge(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(title)
                        .font(TypographyTokens.body)
                    if let subtitle {
                        Text(subtitle)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: SpacingTokens.xSmall)

                if let accessory {
                    Text(accessory)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityComposition)
        }
    }
}

// MARK: - Accessibility composition

private extension SettingsNavigationRow {

    /// Combines the row's title with a spoken status phrase (e.g.
    /// "Notifications, on") so VoiceOver carries the same glance-
    /// level information as the visible accessory chip without
    /// double-announcing the literal text.
    var accessibilityComposition: Text {
        var combined = Text(title)
        if let accessibilityStatus {
            combined = Text("\(combined), \(Text(accessibilityStatus))")
        }
        return combined
    }
}
