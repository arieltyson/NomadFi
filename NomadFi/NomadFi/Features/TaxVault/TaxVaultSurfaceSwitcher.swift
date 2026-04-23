// TaxVaultSurfaceSwitcher.swift
// NomadFi
//
// Segmented peer-surface switcher. Sits just under the navigation
// title so the first viewport shows both the surface label and the
// primary action. Follows HIG segmented-control guidance: no more
// than a handful of peers, every label is a noun, every item has
// a complementary SF Symbol for Differentiate-Without-Color.

import SwiftUI

struct TaxVaultSurfaceSwitcher: View {

    @Binding var selection: TaxVaultSurface

    var body: some View {
        Picker("Tax Vault mode", selection: $selection) {
            ForEach(TaxVaultSurface.allCases) { surface in
                Label(surface.title, systemImage: surface.systemImage)
                    .tag(surface)
                    .accessibilityLabel(surface.accessibilityLabel)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, SpacingTokens.medium)
        .padding(.top, SpacingTokens.xSmall)
        .padding(.bottom, SpacingTokens.xSmall)
        .background(ColorTokens.surfacePrimary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tax Vault mode")
    }
}
