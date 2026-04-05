import Foundation
import Supabase

/// NotificationRepositoryProtocol の Supabase実装
final class SupabaseNotificationRepository: NotificationRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchNotifications(cursor: Date?, limit: Int) async throws -> [NotificationDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [NotificationDTO] = try await client
                .from("notifications")
                .select()
                .lt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        } else {
            let result: [NotificationDTO] = try await client
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        }
    }

    func fetchUnreadCount() async throws -> Int {
        let response = try await client
            .from("notifications")
            .select("*", head: true, count: .exact)
            .eq("is_read", value: false)
            .execute()
        return response.count ?? 0
    }

    func markAsRead(id: UUID) async throws {
        try await client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markAllAsRead() async throws {
        try await client
            .from("notifications")
            .update(["is_read": true])
            .eq("is_read", value: false)
            .execute()
    }
}
