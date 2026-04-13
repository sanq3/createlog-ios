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
}
