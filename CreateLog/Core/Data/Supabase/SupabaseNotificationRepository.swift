import Foundation
import Supabase

/// NotificationRepositoryProtocol の Supabase実装
final class SupabaseNotificationRepository: NotificationRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    /// 2026-04-20: actor (発信者) の profile 情報を JOIN で取得する select 句。
    /// 従来の `.select()` のみだと actor_display_name / actor_handle が常に nil で、
    /// UI で "someone" fallback になる既存 bug の根本修正。NotificationDTO の decoder が
    /// nested `actor` を優先 decode する (PostDTO 同 pattern)。
    private static let notificationSelectClause = "*, actor:profiles!notifications_actor_id_fkey(handle, display_name, avatar_url)"

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchNotifications(cursor: Date?, limit: Int) async throws -> [NotificationDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [NotificationDTO] = try await client
                .from("notifications")
                .select(Self.notificationSelectClause)
                .lt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        } else {
            let result: [NotificationDTO] = try await client
                .from("notifications")
                .select(Self.notificationSelectClause)
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
