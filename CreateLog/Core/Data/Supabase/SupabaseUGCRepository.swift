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
}
