// AccountListing.swift
// NomadFi
//
// Search, ordering and select-all shared by the Settings lists of
// accounts (Accounts, Credit Card Calendar).

import Foundation
import SwiftData

/// The rules every Settings list of accounts follows, so they search,
/// sort and select the same way.
enum AccountListing {

    /// `accounts` whose name or institution matches `query`, by
    /// institution and then name.
    static func visible(_ accounts: [Account], matching query: String) -> [Account] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts
            .filter {
                query.isEmpty
                    || $0.name.localizedStandardContains(query)
                    || $0.institutionName.localizedStandardContains(query)
            }
            .sorted {
                let institution = $0.institutionName.localizedStandardCompare($1.institutionName)
                return institution == .orderedSame
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : institution == .orderedAscending
            }
    }

    /// Whether every one of `visible` is in `selection`.
    static func isAllSelected(_ selection: Set<PersistentIdentifier>, in visible: [Account]) -> Bool {
        !visible.isEmpty && visible.allSatisfy { selection.contains($0.persistentModelID) }
    }

    /// Every one of `visible` selected — or none, if all already were.
    static func toggledSelectAll(_ selection: Set<PersistentIdentifier>, in visible: [Account]) -> Set<PersistentIdentifier> {
        isAllSelected(selection, in: visible) ? [] : Set(visible.map(\.persistentModelID))
    }

    /// The members of `accounts` that are in `selection`.
    static func selected(_ selection: Set<PersistentIdentifier>, from accounts: [Account]) -> [Account] {
        accounts.filter { selection.contains($0.persistentModelID) }
    }
}
