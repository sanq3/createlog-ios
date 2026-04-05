import Foundation

/// アプリ/ポートフォリオのデータアクセス
protocol AppRepositoryProtocol: Sendable {
    /// 自分のアプリ一覧
    func fetchMyApps() async throws -> [AppDTO]
    /// 指定ユーザーの公開アプリ一覧
    func fetchApps(userId: UUID) async throws -> [AppDTO]
    /// アプリ登録
    func insertApp(_ app: AppInsertDTO) async throws -> AppDTO
    /// アプリ更新
    func updateApp(id: UUID, _ updates: AppInsertDTO) async throws -> AppDTO
    /// アプリ削除
    func deleteApp(id: UUID) async throws
}
