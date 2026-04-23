// TaxVaultSurface.swift
// NomadFi
//
// Peer surfaces inside the Tax Vault destination. Expressed as an
// enum so the shell view, switcher, and tests share one source of
// truth for labels, SF Symbols, and accessibility copy.
//
// The three surfaces line up with HIG's hierarchy + harmony
// principles: each answers one clear question rather than stacking
// unrelated work in one long list.
//   • `.review`  — "What do I need to act on?"
//   • `.learn`   — "What do I need to understand?"
//   • `.archive` — "What do I already have on file?"

import Foundation

enum TaxVaultSurface: String, Sendable, Equatable, CaseIterable, Identifiable {

    /// Primary actions + the tax-category suggestion queue.
    /// First-viewport scan / upload CTA lives here.
    case review

    /// Source-backed education starter, progression, quizzes, and
    /// calm recognition badges.
    case learn

    /// Searchable document archive grouped by year + jurisdiction
    /// plus the per-year export.
    case archive

    var id: String { rawValue }

    /// Short, direct label rendered inside the segmented switcher
    /// and the navigation title subline. No marketing tone.
    var title: String {
        switch self {
        case .review: "Review"
        case .learn: "Learn"
        case .archive: "Archive"
        }
    }

    /// SF Symbol paired with the title so Differentiate-Without-
    /// Color users still read the mode correctly.
    var systemImage: String {
        switch self {
        case .review: "checkmark.circle"
        case .learn: "books.vertical"
        case .archive: "tray.full"
        }
    }

    /// VoiceOver phrasing for the switcher button. Stays procedural
    /// — never implies filing or compliance.
    var accessibilityLabel: String {
        switch self {
        case .review: "Review. Scan or upload receipts and review tax-category suggestions."
        case .learn: "Learn. Source-backed education and knowledge-check quizzes for your jurisdictions."
        case .archive: "Archive. Search, browse, and export saved tax documents."
        }
    }
}
