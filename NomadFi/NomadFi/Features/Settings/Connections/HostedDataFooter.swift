// HostedDataFooter.swift
// NomadFi
//
// Where bank data is kept, in one quiet footer.

import SwiftUI

/// The storage region, backup retention and privacy policy, under the
/// bank list rather than above it.
struct HostedDataFooter: View {

    let region: String
    let backupRetentionDays: Int
    let privacyPolicyURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxSmall) {
            Text("Stored in \(region). \(retention)")
            if let privacyPolicyURL {
                Link("Privacy Policy", destination: privacyPolicyURL)
            }
        }
    }

    private var retention: String {
        backupRetentionDays == 0
            ? String(localized: "Deleted data isn't kept in backups.")
            : String(localized: "Deleted data can stay in restricted backups for up to \(backupRetentionDays) days.")
    }
}
