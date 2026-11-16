import Foundation

/// Remembers what was suggested for each merchant, including "nothing
/// fits", so each merchant is only ever asked about once.
///
/// Kept in a small file rather than the database: suggestions are a
/// rebuildable cache, not a person's data. It is written with complete
/// file protection, so it is unreadable while the iPhone is locked.
struct SpendingSuggestionStore: Sendable {

    /// Merchant key → subcategory ID; an empty ID means nothing fit.
    typealias Suggestions = [String: String]

    let fileURL: URL

    static let standard = SpendingSuggestionStore(
        fileURL: .applicationSupportDirectory.appending(path: "SpendingSuggestions.json")
    )

    func load() -> Suggestions {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? JSONDecoder().decode(Suggestions.self, from: data)) ?? [:]
    }

    func save(_ suggestions: Suggestions) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(suggestions).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
