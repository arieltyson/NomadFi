import Foundation
import SwiftData

@Model
final class HostedLocalState {
    var ownerID: String = ""
    var endpoint: String = ""
    var deviceID: UUID = UUID()
    var revision: String = "0"
    var eventOffset: Int = -1
    var ledgerData: Data = Data()
    var archivedTransactionsData: Data = Data()
    var lastAppliedAt: Date?

    init(ownerID: UUID, endpoint: URL) {
        self.ownerID = ownerID.uuidString
        self.endpoint = endpoint.absoluteString
    }

    var checkpoint: HostedCheckpoint { .init(revision: revision, offset: eventOffset) }

    func ledger() throws -> [HostedEvent] {
        ledgerData.isEmpty ? [] : try JSONDecoder().decode([HostedEvent].self, from: ledgerData)
    }
}

struct HostedTransactionArchive: Codable, Sendable {
    let identity: String
    let merchantName: String
    let amount: Double
    let currency: String
    let date: Date
    let notes: String
    let jurisdiction: String
    let category: String
    let isTaxDeductible: Bool
    let taxSuggestionStatus: String?
    let taxSuggestionReviewedAt: Date?
    let taxSuggestionCategory: String?
    let convertedAmount: Double
    let homeCurrency: String
    let appliedRate: Double
    let midMarketRate: Double
    let appliedProvenance: SourceProvenance
    let midMarketProvenance: SourceProvenance
    let taxDocumentID: PersistentIdentifier?
}
