import Foundation

/// カテゴリのデータアクセス
protocol CategoryRepositoryProtocol: Sendable {
    /// 全カテゴリ取得 (デフォルト + ユーザーカスタム)
    func fetchCategories() async throws -> [CategoryDTO]
    /// カテゴリ作成
    func insertCategory(_ category: CategoryInsertDTO) async throws -> CategoryDTO
    /// カテゴリ更新
    func updateCategory(id: UUID, name: String?, color: String?, displayOrder: Int?) async throws -> CategoryDTO
    /// カテゴリ削除 (カスタムのみ)
    func deleteCategory(id: UUID) async throws
}
