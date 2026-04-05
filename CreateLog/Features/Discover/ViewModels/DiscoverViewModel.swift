import Foundation

/// 検索・発見画面のViewModel
@MainActor @Observable
final class DiscoverViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let searchRepository: any SearchRepositoryProtocol

    // MARK: - State

    var searchQuery = ""
    var isSearching = false
    var searchResults: SearchResults?
    var trendingTags: [String] = []
    var suggestedUsers: [ProfileDTO] = []
    var errorMessage: String?

    var isShowingResults: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Init

    init(searchRepository: any SearchRepositoryProtocol) {
        self.searchRepository = searchRepository
    }

    // MARK: - Actions

    func loadInitialData() async {
        do {
            async let tags = searchRepository.fetchTrendingTags()
            async let users = searchRepository.fetchSuggestedUsers(limit: 10)
            trendingTags = try await tags
            suggestedUsers = try await users
        } catch {
            // サイレント
        }
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = nil
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await searchRepository.search(query: query, limit: 20)
        } catch {
            errorMessage = "検索に失敗しました"
        }
    }
}
