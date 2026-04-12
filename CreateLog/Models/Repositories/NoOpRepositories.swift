import Foundation

/// ローカルのみで動作するno-op LogRepository (プレビュー・SwiftDataオフライン専用)
/// テスト用モックとしても使用可能
struct NoOpLogRepository: LogRepositoryProtocol {
    func fetchLogs(for date: Date) async throws -> [LogDTO] { [] }
    func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO] { [] }
    func insertLog(_ log: LogInsertDTO) async throws -> LogDTO {
        throw NetworkError.notAuthenticated
    }
    func updateLog(_ update: LogUpdateDTO) async throws -> LogDTO {
        throw NetworkError.notAuthenticated
    }
    func deleteLog(id: UUID) async throws {}
}

struct NoOpCategoryRepository: CategoryRepositoryProtocol {
    func fetchCategories() async throws -> [CategoryDTO] { [] }
    func insertCategory(_ category: CategoryInsertDTO) async throws -> CategoryDTO {
        throw NetworkError.notAuthenticated
    }
    func updateCategory(id: UUID, name: String?, color: String?, displayOrder: Int?) async throws -> CategoryDTO {
        throw NetworkError.notAuthenticated
    }
    func deleteCategory(id: UUID) async throws {}
}

/// プレビュー・未認証時のフォールバック用 ProfileRepository
struct NoOpProfileRepository: ProfileRepositoryProtocol {
    func fetchMyProfile() async throws -> ProfileDTO {
        throw NetworkError.notAuthenticated
    }
    func fetchProfile(userId: UUID) async throws -> ProfileDTO {
        throw NetworkError.notAuthenticated
    }
    func updateProfile(_ updates: ProfileUpdateDTO) async throws -> ProfileDTO {
        throw NetworkError.notAuthenticated
    }
    func checkHandleAvailability(_ handle: String) async throws -> Bool { true }
}

/// T4 (2026-04-12): NoOp SubscriptionRepository (Preview 用)
struct NoOpSubscriptionRepository: SubscriptionRepositoryProtocol {
    func fetchCurrentSubscription() async throws -> SubscriptionDTO? { nil }
    func upsertFromStoreKit(_ upsert: SubscriptionUpsertDTO) async throws -> SubscriptionDTO {
        throw NetworkError.notAuthenticated
    }
}

/// T4 (2026-04-12): NoOp MonthlyRevenueRepository (Preview 用)
struct NoOpMonthlyRevenueRepository: MonthlyRevenueRepositoryProtocol {
    func fetchRevenues(userId: UUID, year: Int?) async throws -> [MonthlyRevenueDTO] { [] }
    func upsertRevenue(_ upsert: MonthlyRevenueUpsertDTO) async throws -> MonthlyRevenueDTO {
        throw NetworkError.notAuthenticated
    }
    func deleteRevenue(id: UUID) async throws {}
}

/// T4 (2026-04-12): NoOp HashtagRepository (Preview 用)
struct NoOpHashtagRepository: HashtagRepositoryProtocol {
    func fetchTrending(limit: Int) async throws -> [HashtagDTO] { [] }
    func fetchByPost(postId: UUID) async throws -> [HashtagDTO] { [] }
}

/// T4 (2026-04-12): NoOp AutoTrackingRepository (Preview 用)
struct NoOpAutoTrackingRepository: AutoTrackingRepositoryProtocol {
    func fetchRecentHeartbeats(limit: Int) async throws -> [HeartbeatDTO] { [] }
    func listMyApiKeys() async throws -> [ApiKeyDTO] { [] }
    func revokeApiKey(id: UUID) async throws {}
    func createApiKey(name: String) async throws -> ApiKeyDTO {
        throw NetworkError.notAuthenticated
    }
}

/// プレビュー・ModelContainer 未注入時のフォールバック用 SyncService。
/// 全 method が no-op、state は常に .idle を返す。
/// `DependencyContainerKey.defaultValue` 経路で使われる想定。
struct NoOpSyncService: SyncServiceProtocol {
    var deadLetterCount: Int { get async { 0 } }
    func start() async {}
    func stop() async {}
    func enqueue(_ snapshot: QueuedOperationSnapshot) async {}
    func flush() async {}
    func observeState() -> AsyncStream<SyncState> {
        AsyncStream { continuation in
            continuation.yield(.idle)
            continuation.finish()
        }
    }
}
