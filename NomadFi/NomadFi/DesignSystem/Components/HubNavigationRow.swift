// HubNavigationRow.swift
// NomadFi
//
// The row a hub screen — Settings, Tools — pushes its pages from.

import SwiftUI

/// A `NavigationLink` row styled like Apple's Settings: tinted icon
/// badge, title, an optional trailing value ("On" / "Off"), and the
/// native chevron.
///
/// Title only, by design. The destination says what it is; a subtitle
/// under every row just restates it.
struct HubNavigationRow<Destination: View>: View {

    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let value: LocalizedStringKey?
    @ViewBuilder var destination: () -> Destination

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color = ColorTokens.brandPrimary,
        value: LocalizedStringKey? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.value = value
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            LabeledContent {
                if let value {
                    Text(value)
                }
            } label: {
                Label {
                    Text(title)
                } icon: {
                    TintedIconBadge(systemImage: systemImage, tint: tint)
                }
            }
        }
    }
}
