import Foundation
import Supabase

/// AutoTrackingRepositoryProtocol の Supabase 実装
///
/// T4 (2026-04-12):
/// - heartbeats: read-only (list のみ、write は外部拡張が担当)
/// - api_keys: list / revoke のみ、create は **Edge Function 必須 (security)**
final class SupabaseAutoTrackingRepository: AutoTrackingRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchRecentHeartbeats(limit: Int) async throws -> [HeartbeatDTO] {
        let session = try await client.auth.session
        let result: [HeartbeatDTO] = try await client
            .from("heartbeats")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("timestamp", ascending: false)
            .limit(limit)
            .execute()
            .value
        return result
    }

    func listMyApiKeys() async throws -> [ApiKeyDTO] {
        let session = try await client.auth.session
        let result: [ApiKeyDTO] = try await client
            .from("api_keys")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        return result
    }

    func revokeApiKey(id: UUID) async throws {
        struct Patch: Encodable { let isActive: Bool; enum CodingKeys: String, CodingKey { case isActive = "is_active" } }
        try await client
            .from("api_keys")
            .update(Patch(isActive: false))
            .eq("id", value: id.uuidString)
            .execute()
    }

    func createApiKey(name: String) async throws -> ApiKeyDTO {
        // v1 未実装: client 平文生成は reverse engineering risk。
        // Edge Function `create-api-key` で server-side に key 生成 + hash 保存する設計。
        throw NetworkError.notAuthenticated
    }
}
