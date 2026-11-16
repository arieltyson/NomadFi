import Foundation
import FoundationModels

/// Asks the on-device Apple Intelligence model which kind of spending a
/// merchant is. Nothing leaves the iPhone, and guided generation limits
/// the answer to the offered IDs or "none", so it can never invent a kind.
struct FoundationModelsSpendingSuggester: SpendingMerchantSuggesting {

    private static let noFit = "none"

    private static let instructions = """
        You sort card purchases into kinds of spending using only the merchant's name. \
        Choose the one kind the name clearly points to. \
        If the name does not clearly point to one kind, choose none.
        """

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func suggest(
        merchantName: String,
        category: TransactionCategory,
        options: [SpendingSubcategory]
    ) async throws -> String? {
        guard isAvailable, !options.isEmpty else { return nil }

        let schema = try GenerationSchema(
            root: DynamicGenerationSchema(
                name: "SpendingKind",
                description: "The ID of the kind of spending, or none.",
                anyOf: options.map(\.id) + [Self.noFit]
            ),
            dependencies: []
        )
        let kinds = options.map { "\($0.id): \($0.name)" }.joined(separator: "\n")
        let prompt = """
            Category: \(category.displayName)
            Merchant: \(merchantName)
            Kinds:
            \(kinds)
            """

        // A fresh session per merchant keeps each answer independent and
        // the context small.
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: prompt,
            schema: schema,
            options: GenerationOptions(sampling: .greedy)
        )
        let id = try response.content.value(String.self)
        return id == Self.noFit ? nil : id
    }
}
