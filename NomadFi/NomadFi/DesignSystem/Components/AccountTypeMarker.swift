// AccountTypeMarker.swift
// NomadFi
//
// Design-system primitive: a small, Dynamic-Type-safe capsule chip
// that labels an account by type (credit card, checking, wallet, …)
// without the user having to encode the type into the account name.
//
// Lives in the design system so every surface that shows account
// identity — Settings rows, credit-card calendar rows, Dashboard
// account cards, scenario linked-card pickers, onboarding lists —
// can adopt a single visual language for the type marker.
//
// The chip is decorative by default; the enclosing view carries the
// account-type phrase in its VoiceOver label via
// ``AccountTypeMarker/accessibilityPhrase(for:)``.

import SwiftUI

/// Inline capsule chip that names an account type next to its row
/// title. Collapses gracefully at accessibility text sizes because
/// the caller nests it inside `ViewThatFits` (or similar) — this
/// component itself never wraps or truncates.
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

    /// Readable VoiceOver phrase — parent rows splice this into their
    /// combined accessibility label so the audio story explicitly
    /// names the type even when the visual chip is hidden.
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
