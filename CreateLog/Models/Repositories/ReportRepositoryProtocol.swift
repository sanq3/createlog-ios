import Foundation

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
}
