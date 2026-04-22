// SettingsNavigationRow.swift
// NomadFi
//
// A consistent, Apple-Settings-style row that pushes a focused
// subpage. The Settings hub composes these rows so the root screen
// stays short, scannable, and visually calm.

import SwiftUI

/// A `NavigationLink` row styled like Apple's Settings hub:
/// SF-symbol badge, title, one-line subtitle, native chevron.
///
/// Keeps copy deliberately short — the detail page is where full
/// descriptions live. The badge tint stays inside the brand palette;
/// destructive rows should use a dedicated `Button`, not this row.
struct SettingsNavigationRow<Destination: View>: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let systemImage: String
    var tint: Color = ColorTokens.brandPrimary
    @ViewBuilder var destination: () -> Destination

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = ColorTokens.brandPrimary,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
                    Text(title)
                        .font(TypographyTokens.body)
                    if let subtitle {
                        Text(subtitle)
                            .font(TypographyTokens.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
        }
    }
}
