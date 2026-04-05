import Foundation

/// 作業ログのデータアクセス
protocol LogRepositoryProtocol: Sendable {
    /// 指定日のログ一覧を取得
    func fetchLogs(for date: Date) async throws -> [LogDTO]
    /// 期間内のログ一覧を取得
    func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO]
    /// ログを保存
    func insertLog(_ log: LogInsertDTO) async throws -> LogDTO
    /// ログを削除
    func deleteLog(id: UUID) async throws
}
