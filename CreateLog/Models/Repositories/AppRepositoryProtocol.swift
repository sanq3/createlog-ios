import Foundation

/// アプリ/ポートフォリオのデータアクセス
protocol AppRepositoryProtocol: Sendable {
    /// 自分のアプリ一覧
    func fetchMyApps() async throws -> [AppDTO]
    /// 指定ユーザーの公開アプリ一覧
    func fetchApps(userId: UUID) async throws -> [AppDTO]
    /// Discover 用: 全ユーザーの全マイプロダクトを `last_bumped_at` DESC で取得 (status 問わず、
    /// 開発中/公開中/停止 すべて含む)。cursor は最古の `apps.last_bumped_at`。
    /// profiles を 2-step fetch + client-side merge で author basic を載せる。
    func fetchAllApps(cursor: Date?, limit: Int) async throws -> [AppDTO]
    /// アプリ登録
    func insertApp(_ app: AppInsertDTO) async throws -> AppDTO
    /// アプリ更新
    func updateApp(id: UUID, _ updates: AppInsertDTO) async throws -> AppDTO
    /// アプリ削除
    func deleteApp(id: UUID) async throws
    /// アプリアイコン画像を Supabase Storage にアップロードして公開 URL を返す。
    /// オンボーディングで選択された SDProject.iconImageData を `apps.icon_url` 用に確定する。
    func uploadAppIcon(imageData: Data, contentType: String) async throws -> URL
}
