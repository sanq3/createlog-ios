import Foundation
import Supabase

/// AppRepositoryProtocol の Supabase実装
final class SupabaseAppRepository: AppRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchMyApps() async throws -> [AppDTO] {
        let session = try await client.auth.session
        let result: [AppDTO] = try await client
            .from("apps")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return result
    }

    func fetchApps(userId: UUID) async throws -> [AppDTO] {
        let result: [AppDTO] = try await client
            .from("apps")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: "published")
            .order("created_at", ascending: false)
            .execute()
            .value
        return result
    }

    func insertApp(_ app: AppInsertDTO) async throws -> AppDTO {
        let result: AppDTO = try await client
            .from("apps")
            .insert(app)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func updateApp(id: UUID, _ updates: AppInsertDTO) async throws -> AppDTO {
        let result: AppDTO = try await client
            .from("apps")
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func deleteApp(id: UUID) async throws {
        try await client
            .from("apps")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
