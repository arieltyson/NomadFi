// TaxDocumentOrganizationPromptKind.swift
// NomadFi
//
// Discriminator for `TaxDocumentOrganizationPrompt`. Three kinds
// today; new kinds must come in with an explicit derivation rule
// in `TaxDocumentOrganizationPromptService` and matching test
// coverage.

import Foundation

/// Type of organization prompt the Tax Vault Learn surface can
/// emit. Each kind maps to a deterministic derivation rule.
enum TaxDocumentOrganizationPromptKind: String, Sendable, Equatable, Hashable, CaseIterable {

    /// User has no documents on file for the region's tax year.
    /// Bridges the user toward Review so they can scan or upload
    /// the first one.
    case scanFirstDocument

    /// User already has documents on file for the region. Bridges
    /// them toward Archive to verify the year / jurisdiction
    /// grouping the app inferred at scan time.
    case verifyArchive

    /// Jurisdiction-specific procedural recordkeeping reminder
    /// linked to the relevant regulator page. Education-only — no
    /// retention guarantee, no filing instruction.
    case recordkeepingPrinciples
}
