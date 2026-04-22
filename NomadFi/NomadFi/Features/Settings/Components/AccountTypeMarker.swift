// AccountTypeMarker.swift
// NomadFi
//
// A small, Dynamic-Type-safe SF-symbol chip shown alongside account
// names to convey account type without requiring the user to write
// "(Credit)" or similar into the name field. Chip layout collapses
// gracefully at accessibility text sizes.

import SwiftUI

/// Inline type marker displayed next to account titles (e.g. the
/// `creditcard.fill` chip after an Amex Cobalt card's name).
///
/// The marker is purely decorative: VoiceOver gets an explicit
/// "credit card" phrase from the row's accessibility label, never
/// from this symbol. That keeps the audio story correct even when the
/// user hides symbols via the Differentiate Without Color setting —
/// and avoids shouting "image" over every account row.
struct AccountTypeMarker: View {

    let accountType: AccountType

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Image(systemName: accountType.systemImage)
            .imageScale(.small)
            .font(TypographyTokens.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, SpacingTokens.xxSmall)
            .padding(.vertical, 2)
            .background(backgroundColor, in: .capsule)
            .overlay {
                if colorSchemeContrast == .increased {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.6), lineWidth: 1)
                }
            }
            .accessibilityHidden(true)
    }

    /// Readable label — used by parent rows to build VoiceOver
    /// descriptions that explicitly name the account type.
    static func accessibilityPhrase(for accountType: AccountType) -> String {
        accountType.displayName.lowercased()
    }

    private var foregroundColor: Color {
        switch accountType {
        case .creditCard: ColorTokens.brandPrimary
        default: ColorTokens.neutral
        }
    }

    private var backgroundColor: Color {
        let increased = colorSchemeContrast == .increased
        switch accountType {
        case .creditCard:
            return ColorTokens.brandPrimary.opacity(increased ? 0.26 : 0.14)
        default:
            return Color.secondary.opacity(increased ? 0.26 : 0.14)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: SpacingTokens.small) {
        HStack {
            Text("Amex Cobalt Canada").font(TypographyTokens.body).bold()
            AccountTypeMarker(accountType: .creditCard)
        }
        HStack {
            Text("CIBC Chequing").font(TypographyTokens.body).bold()
            AccountTypeMarker(accountType: .checking)
        }
    }
    .padding()
}
