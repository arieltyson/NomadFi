// TaxDocumentJurisdictionGroup.swift
// NomadFi
//
// One jurisdiction's documents within an Archive tax year.

import Foundation

/// The documents filed under one jurisdiction, or under none the
/// person has set up.
struct TaxDocumentJurisdictionGroup: Identifiable {

    /// The country code, or ``otherID`` for documents whose
    /// jurisdiction matches no profile.
    let id: String

    /// The section heading.
    let title: String

    let documents: [TaxDocument]

    /// Identifies the group for documents with no matching profile —
    /// saved without a jurisdiction, or under one since removed.
    static let otherID = "other"
}
