import Foundation

/// ローカルのみで動作するno-op LogRepository (プレビュー・SwiftDataオフライン専用)
/// テスト用モックとしても使用可能
struct NoOpLogRepository: LogRepositoryProtocol {
    func fetchLogs(for date: Date) async throws -> [LogDTO] { [] }
    func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO] { [] }
    func insertLog(_ log: LogInsertDTO) async throws -> LogDTO {
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
