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

    /// Discover 用: 全ユーザーの apps を `last_bumped_at` DESC で新着順取得 + 作者 basic を別 query で client-side merge。
    /// status フィルタは無し (開発中/公開中/停止 全部表示)。RLS は「公開アプリは全認証ユーザー閲覧可」だが、
    /// Discover コンセプト刷新で draft/archived も他人に見せたい (宣伝目的) 方針。RLS 側を緩める必要がある。
    /// 現行 RLS が published のみ許可ならサーバー側で 0 件返るので、同時に RLS 緩和 migration が別途必要になる可能性あり。
    ///
    /// **2 step fetch の理由**: `apps.user_id` → `auth.users.id` の FK のため、PostgREST で
    /// `profiles!apps_user_id_fkey` 形式の JOIN が書けない (profiles への直接 FK なし)。
    /// userIds を抽出 → profiles を `.in` でバッチ fetch → Dictionary lookup で merge する。N+1 ではない。
    func fetchAllApps(cursor: Date?, limit: Int) async throws -> [AppDTO] {
        let formatter = ISO8601DateFormatter()
        var apps: [AppDTO]
        if let cursor {
            apps = try await client
                .from("apps")
                .select()
                .lt("last_bumped_at", value: formatter.string(from: cursor))
                .order("last_bumped_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            apps = try await client
                .from("apps")
                .select()
                .order("last_bumped_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }

        guard !apps.isEmpty else { return apps }

        let userIds = Array(Set(apps.map(\.userId))).map(\.uuidString)
        let profiles: [ProfileDTO] = try await client
            .from("profiles")
            .select()
            .in("id", values: userIds)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        for index in apps.indices {
            guard let profile = profileMap[apps[index].userId] else { continue }
            apps[index].authorDisplayName = profile.displayName
            apps[index].authorHandle = profile.handle
            apps[index].authorAvatarUrl = profile.avatarUrl
        }
        return apps
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

    /// アイコンを Supabase Storage `avatars` bucket に upload。新しい bucket を作る migration を避けるため、
    /// path を `{userId}/apps/{timestamp}.{ext}` で名前空間を分けて user avatar と共存させる。
    /// (avatars bucket の RLS は `auth.uid() = storage prefix` 想定なので prefix を userId にすれば適用される)
    ///
    /// **重要**: `UUID.uuidString` は uppercase を返すが Postgres `auth.uid()::text` は lowercase。
    /// `.lowercased()` を必ず付ける (RLS の path prefix 比較が大文字小文字 sensitive)。
    func uploadAppIcon(imageData: Data, contentType: String) async throws -> URL {
        let session = try await client.auth.session
        let ext = contentType.contains("png") ? "png" : "jpg"
        let userIdLower = session.user.id.uuidString.lowercased()
        let path = "\(userIdLower)/apps/\(Int(Date().timeIntervalSince1970)).\(ext)"

        _ = try await client.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: contentType, upsert: true)
            )

        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        return publicURL
    }
}
