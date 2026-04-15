import Foundation

/// ユーザープロフィールのデータアクセス
protocol ProfileRepositoryProtocol: Sendable {
    /// 自分のプロフィール取得
    func fetchMyProfile() async throws -> ProfileDTO
    /// 指定ユーザーのプロフィール取得
    func fetchProfile(userId: UUID) async throws -> ProfileDTO
    /// プロフィール更新
    func updateProfile(_ updates: ProfileUpdateDTO) async throws -> ProfileDTO
    /// ハンドルの利用可否チェック
    func checkHandleAvailability(_ handle: String) async throws -> Bool
    /// アバター画像を Supabase Storage にアップロードして公開 URL を返す
    func uploadAvatar(imageData: Data, contentType: String) async throws -> URL

    // MARK: - SWR cache reads (default: no cache)
    //
    // 同期的に cache から profile を返す。初回表示の flicker 対策 (Bluesky placeholderData 相当)。
    // Decorator (`OfflineFirstProfileRepository`) のみが実装、Supabase / NoOp は default (nil) を使う。

    /// 自分の profile を同期的に cache から取得。cold cache / 非対応実装では nil。
    func cachedMyProfile() -> ProfileDTO?
    /// 指定ユーザーの profile を同期的に cache から取得。cold cache / 非対応実装では nil。
    func cachedProfile(userId: UUID) -> ProfileDTO?

    /// Feed / Comment / Notification 取得時に得られた author 3 フィールドを cache に先行書き込みする。
    /// Bluesky feed-precache pattern。初回プロフィール遷移時の spinner を抑える。
    /// 既存 row があれば basic 3 field のみ更新 (他 field は保持)、無ければ minimal row を insert。
    func precacheBasic(userId: UUID, handle: String?, displayName: String?, avatarUrl: String?)
}

extension ProfileRepositoryProtocol {
    // MARK: - Default: no cache (Supabase 直接実装 / NoOp 用)
    func cachedMyProfile() -> ProfileDTO? { nil }
    func cachedProfile(userId: UUID) -> ProfileDTO? { nil }
    func precacheBasic(userId: UUID, handle: String?, displayName: String?, avatarUrl: String?) {}
}
