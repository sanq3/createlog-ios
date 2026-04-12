import Foundation

/// Supabase `heartbeats` テーブル対応 DTO
///
/// T4 (2026-04-12): エディタ・デスクトップアプリからの heartbeat イベント
/// iOS 側は **read-only**。書き込みは VS Code / Claude Code / Codex / Desktop 拡張が担う。
struct HeartbeatDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    /// "vscode" / "claude_code" / "codex" / "desktop"
    let source: String
    let projectName: String
    let filePath: String
    let language: String
    let categoryId: UUID?
    let timestamp: Date
    let isProcessed: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case source
        case projectName = "project_name"
        case filePath = "file_path"
        case language
        case categoryId = "category_id"
        case timestamp
        case isProcessed = "is_processed"
        case createdAt = "created_at"
    }
}
