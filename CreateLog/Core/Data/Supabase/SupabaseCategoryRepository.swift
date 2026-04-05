import Foundation
import Supabase

/// CategoryRepositoryProtocol の Supabase実装
final class SupabaseCategoryRepository: CategoryRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchCategories() async throws -> [CategoryDTO] {
        // userId はSupabaseセッションから取得したUUID (インジェクション不可)
        let userId = try await currentUserId()
        let result: [CategoryDTO] = try await client
            .from("categories")
            .select()
            .or("user_id.is.null,user_id.eq.\(userId)")
            .eq("is_active", value: true)
            .order("display_order")
            .execute()
            .value

        return result
    }

    func insertCategory(_ category: CategoryInsertDTO) async throws -> CategoryDTO {
        let result: CategoryDTO = try await client
            .from("categories")
            .insert(category)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    func updateCategory(id: UUID, name: String?, color: String?, displayOrder: Int?) async throws -> CategoryDTO {
        var updates: [String: AnyEncodable] = [:]
        if let name { updates["name"] = AnyEncodable(name) }
        if let color { updates["color"] = AnyEncodable(color) }
        if let displayOrder { updates["display_order"] = AnyEncodable(displayOrder) }

        let result: CategoryDTO = try await client
            .from("categories")
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    func deleteCategory(id: UUID) async throws {
        try await client
            .from("categories")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Helpers

    private func currentUserId() async throws -> String {
        let session = try await client.auth.session
        return session.user.id.uuidString
    }
}

// MARK: - AnyEncodable

/// 部分更新用のtype-erasedエンコーダブル
private struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init<T: Encodable & Sendable>(_ value: T) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
