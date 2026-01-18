import Foundation

/// Manages recent search history using UserDefaults
class SearchHistoryManager {
    static let shared = SearchHistoryManager()

    private let maxItems = 10
    private let searchHistoryKey = "recentSearches"

    private init() {}

    // MARK: - Public API

    /// Get all recent searches
    var recentSearches: [String] {
        UserDefaults.standard.stringArray(forKey: searchHistoryKey) ?? []
    }

    /// Add a search term to history
    /// - Parameter searchTerm: The search term to add
    func addSearch(_ searchTerm: String) {
        let trimmed = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var searches = recentSearches

        // Remove if already exists (will be re-added at top)
        searches.removeAll { $0.lowercased() == trimmed.lowercased() }

        // Add to beginning
        searches.insert(trimmed, at: 0)

        // Trim to max items
        if searches.count > maxItems {
            searches = Array(searches.prefix(maxItems))
        }

        UserDefaults.standard.set(searches, forKey: searchHistoryKey)
    }

    /// Remove a specific search term from history
    /// - Parameter searchTerm: The search term to remove
    func removeSearch(_ searchTerm: String) {
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == searchTerm.lowercased() }
        UserDefaults.standard.set(searches, forKey: searchHistoryKey)
    }

    /// Clear all search history
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }

    /// Check if a search term exists in history
    /// - Parameter searchTerm: The search term to check
    /// - Returns: True if the term exists in history
    func hasSearch(_ searchTerm: String) -> Bool {
        recentSearches.contains { $0.lowercased() == searchTerm.lowercased() }
    }
}
