import Foundation
import Supabase

/// UGCRepositoryProtocol の Supabase実装
final class SupabaseUGCRepository: UGCRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func reportContent(targetId: UUID, targetType: String, reason: String, detail: String?) async throws {
        let session = try await client.auth.session
        var params: [String: String] = [
            "reporter_id": session.user.id.uuidString,
            "target_id": targetId.uuidString,
            "target_type": targetType,
            "reason": reason
        ]
        if let detail, !detail.isEmpty {
            // DB 側カラム名は `description` (reports table)。`detail` にすると silent に破棄される。
            params["description"] = detail
        }
        try await client
            .from("reports")
            .insert(params)
            .execute()
    }

    func blockUser(userId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("blocks")
            .insert([
                "blocker_id": session.user.id.uuidString,
                "blocked_id": userId.uuidString
            ])
            .execute()
    }

    func unblockUser(userId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("blocks")
            .delete()
            .eq("blocker_id", value: session.user.id.uuidString)
            .eq("blocked_id", value: userId.uuidString)
            .execute()
    }

    func isBlocked(userId: UUID) async throws -> Bool {
        let session = try await client.auth.session
        struct BlockRow: Codable { let id: UUID }
        let result: [BlockRow] = try await client
            .from("blocks")
            .select("id")
            .eq("blocker_id", value: session.user.id.uuidString)
            .eq("blocked_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return !result.isEmpty
    }

    func fetchBlockedUsers() async throws -> [BlockedUserRow] {
        let session = try await client.auth.session

        // blocks を時系列 desc で取得して blocked_id を profiles と JOIN。
        // PostgREST nested select で 1 round-trip で済ませる (N+1 回避)。
        struct Row: Decodable {
            let blocked_id: UUID
            let blocked: Blocked?
            struct Blocked: Decodable {
                let id: UUID
                let display_name: String?
                let handle: String?
                let avatar_url: String?
            }
        }

        let rows: [Row] = try await client
            .from("blocks")
            .select("blocked_id, blocked:profiles!blocks_blocked_id_fkey(id, display_name, handle, avatar_url)")
            .eq("blocker_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        // profile 取得失敗した row (ユーザー削除済み等) は placeholder として最低限の表示で残す。
        // 解除 UI を出すために id だけは必ず保持する。
        return rows.map { row in
            BlockedUserRow(
                id: row.blocked?.id ?? row.blocked_id,
                displayName: row.blocked?.display_name ?? "Unknown",
                handle: row.blocked?.handle,
                avatarUrl: row.blocked?.avatar_url
            )
        }
    }
}
