// ActiveCardIntent.swift
// NomadFi
//
// Siri shortcut: "Hey Siri, which card should I use?"
// Recommends the optimal payment card for the user's current location.

import AppIntents
import CoreLocation
import SwiftData

/// Recommends the best payment card based on the user's current location.
///
/// Checks the user's accounts and suggests the one with the lowest
/// foreign transaction fee for their current country. Falls back to
/// a general recommendation if location is unavailable.
///
/// Usage: "Hey Siri, which card should I use?"
struct ActiveCardIntent: AppIntent {

    static let title: LocalizedStringResource = "Which Card Should I Use?"

    static let description: IntentDescription = "Get a recommendation for the best card to use at your current location."

    static let openAppWhenRun = false

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: Account.self)
        let context = container.mainContext

        // Sort by foreign transaction fee in the query to avoid in-memory sorting.
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.foreignTransactionFeePercent)]
        )
        let accounts = try context.fetch(descriptor)

        guard let bestCard = accounts.first else {
            return .result(dialog: "You don't have any accounts set up yet. Open NomadFi to add your cards.")
        }

        let fee = bestCard.foreignTransactionFeePercent
        let provenance = bestCard.foreignTransactionFeeProvenance
        let effective = SourceFreshness.effectiveConfidence(
            for: provenance,
            domain: .issuerCardTerms
        )
        // The caveat distinguishes three cases so the spoken dialog is
        // honest about *why* a fee is not verified: never verified,
        // verified but now stale, or verified and fresh.
        let caveat: String
        switch effective {
        case .verifiedPrimary, .verifiedSecondary:
            caveat = ""
        case .unverified where provenance.confidence.isVerified:
            caveat = " Heads up, your issuer terms for this card haven't been re-checked lately, so it's worth verifying."
        default:
            caveat = " This is based on fee data you saved, not confirmed with the issuer."
        }

        if fee == 0 {
            return .result(
                dialog: "Use your \(bestCard.name). It has no foreign transaction fees on record.\(caveat)"
            )
        } else {
            let feeFormatted = fee.formatted(.number.precision(.fractionLength(1)))
            return .result(
                dialog: "Use your \(bestCard.name). It has the lowest foreign transaction fee on record at \(feeFormatted)%.\(caveat)"
            )
        }
    }
}
