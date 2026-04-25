// TaxDocumentOrganizationPromptTarget.swift
// NomadFi
//
// Where a prompt's primary action should send the user. Kept as a
// pure value so the service stays UI-agnostic and the surface
// (`TaxVaultView`) can wire the actual peer-surface switch.

import Foundation

/// Routing intent for a prompt's primary action. `.none` means the
/// prompt is informational only — the card renders its source link
/// but no surface-switch button.
enum TaxDocumentOrganizationPromptTarget: String, Sendable, Equatable, Hashable {
    case review
    case archive
    case none
}
