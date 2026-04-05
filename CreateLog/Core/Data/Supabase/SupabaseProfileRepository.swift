import Foundation
import Supabase

/// ProfileRepositoryProtocol の Supabase実装
final class SupabaseProfileRepository: ProfileRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchMyProfile() async throws -> ProfileDTO {
        let session = try await client.auth.session
        return try await fetchProfile(userId: session.user.id)
    }

    func fetchProfile(userId: UUID) async throws -> ProfileDTO {
        let result: ProfileDTO = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        return result
    }

    func updateProfile(_ updates: ProfileUpdateDTO) async throws -> ProfileDTO {
        let session = try await client.auth.session
        let result: ProfileDTO = try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: session.user.id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func checkHandleAvailability(_ handle: String) async throws -> Bool {
        let result: [ProfileDTO] = try await client
            .from("profiles")
            .select("id")
            .eq("handle", value: handle)
            .limit(1)
            .execute()
            .value
        return result.isEmpty
    }
}
