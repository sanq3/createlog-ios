import Foundation
import Supabase

/// SubscriptionRepositoryProtocol の Supabase 実装
///
/// T4 (2026-04-12): StoreKit 2 + free/premium プラン管理
final class SupabaseSubscriptionRepository: SubscriptionRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchCurrentSubscription() async throws -> SubscriptionDTO? {
        let session = try await client.auth.session
        let result: [SubscriptionDTO] = try await client
            .from("subscriptions")
            .select()
            .eq("user_id", value: session.user.id.uuidString)
            .order("updated_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return result.first
    }

    func upsertFromStoreKit(_ upsert: SubscriptionUpsertDTO) async throws -> SubscriptionDTO {
        // UNIQUE(user_id) 前提、onConflict で update
        let result: SubscriptionDTO = try await client
            .from("subscriptions")
            .upsert(upsert, onConflict: "user_id")
            .select()
            .single()
            .execute()
            .value
        return result
    }
}
