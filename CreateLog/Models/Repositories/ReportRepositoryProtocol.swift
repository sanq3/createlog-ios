import Foundation

/// ブロック一覧表示用の軽量 row (プロフィール必要最小限)。
/// 設定 → プライバシー → ブロック済みアカウント 一覧で使う。
public struct BlockedUserRow: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let displayName: String
    public let handle: String?
    public let avatarUrl: String?
}

/// UGC安全機能のデータアクセス
/// ReportReason は DesignSystem/Components/ReportSheet.swift に定義済み
protocol UGCRepositoryProtocol: Sendable {
    /// コンテンツ報告
    func reportContent(targetId: UUID, targetType: String, reason: String, detail: String?) async throws
    /// ユーザーブロック
    func blockUser(userId: UUID) async throws
    /// ユーザーブロック解除
    func unblockUser(userId: UUID) async throws
    /// ブロック済みか判定
    func isBlocked(userId: UUID) async throws -> Bool
    /// 自分がブロックしたユーザー一覧 (新しい順)。設定画面のブロック一覧で使う。
    func fetchBlockedUsers() async throws -> [BlockedUserRow]
}
