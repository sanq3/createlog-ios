import Foundation

/// 通知のデータアクセス
protocol NotificationRepositoryProtocol: Sendable {
    /// 通知一覧取得 (ページネーション)
    func fetchNotifications(cursor: Date?, limit: Int) async throws -> [NotificationDTO]
    /// 未読数取得
    func fetchUnreadCount() async throws -> Int
    /// 既読にする
    func markAsRead(id: UUID) async throws
    /// 全て既読にする
    func markAllAsRead() async throws
}
