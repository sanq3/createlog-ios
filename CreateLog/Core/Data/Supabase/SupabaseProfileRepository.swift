import Foundation
import Supabase

/// ProfileRepositoryProtocol の Supabase実装
final class SupabaseProfileRepository: ProfileRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Sign In 直後は SDK の session storage 書込みが遅延することがあり
    /// `client.auth.session` が `Auth session missing` を投げる。500ms 間隔で最大 10 回 (計 5 秒) retry する。
    /// (2026-04-14 displayName step の保存失敗を追跡して追加 + 粘り強く拡張)
    private func currentSession() async throws -> Session {
        var lastError: Error?
        for attempt in 0..<10 {
            do {
                let session = try await client.auth.session
                if attempt > 0 {
                    print("[SupabaseProfileRepository] ✅ session obtained after \(attempt) retries")
                }
                return session
            } catch {
                lastError = error
                print("[SupabaseProfileRepository] ⏳ session attempt \(attempt + 1) failed: \(error.localizedDescription)")
                if attempt < 9 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        print("[SupabaseProfileRepository] ❌ session unavailable after 10 retries (5s)")
        throw lastError ?? AuthError.unknown("Session unavailable after retries")
    }

    func fetchMyProfile() async throws -> ProfileDTO {
        let session = try await currentSession()
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
        let session = try await currentSession()
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

    /// Supabase Storage `avatars` bucket にアップロードして公開 URL を返す。
    /// ファイル名は `{userId}/{timestamp}.{ext}` 形式で衝突回避 + user ごとの prefix で RLS 適用しやすく。
    /// bucket 側で `public: true` かつ auth.uid() = storage prefix の RLS policy を想定。
    ///
    /// **重要**: `UUID.uuidString` は uppercase を返すが Postgres `auth.uid()::text` は lowercase。
    /// `.lowercased()` を必ず付ける (RLS の path prefix 比較が大文字小文字 sensitive)。
    func uploadAvatar(imageData: Data, contentType: String) async throws -> URL {
        let session = try await currentSession()
        let ext = contentType.contains("png") ? "png" : "jpg"
        let userIdLower = session.user.id.uuidString.lowercased()
        let path = "\(userIdLower)/\(Int(Date().timeIntervalSince1970)).\(ext)"

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
