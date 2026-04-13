import Foundation

// MARK: - Post Repository

/// 投稿のデータアクセス
protocol PostRepositoryProtocol: Sendable {
    /// フィード取得 (カーソルベースページネーション)
    func fetchFeed(cursor: Date?, limit: Int) async throws -> [PostDTO]
    /// フォロー中ユーザーの投稿取得
    func fetchFollowingFeed(cursor: Date?, limit: Int) async throws -> [PostDTO]
    /// 特定ユーザーの投稿一覧 (プロフィール画面用)
    func fetchUserPosts(userId: UUID, cursor: Date?, limit: Int) async throws -> [PostDTO]
    /// 投稿作成
    func insertPost(_ post: PostInsertDTO) async throws -> PostDTO
    /// 投稿削除
    func deletePost(id: UUID) async throws
}

// MARK: - Follow Repository

/// フォロー関係のデータアクセス
protocol FollowRepositoryProtocol: Sendable {
    /// フォローする
    func follow(userId: UUID) async throws
    /// フォロー解除
    func unfollow(userId: UUID) async throws
    /// フォロー中か判定
    func isFollowing(userId: UUID) async throws -> Bool
    /// フォロワー数/フォロー中数
    func fetchCounts(userId: UUID) async throws -> (followers: Int, following: Int)
    /// 指定ユーザーをフォローしているユーザー一覧 (フォロワー)
    func fetchFollowers(userId: UUID, limit: Int) async throws -> [ProfileDTO]
    /// 指定ユーザーがフォローしているユーザー一覧
    func fetchFollowing(userId: UUID, limit: Int) async throws -> [ProfileDTO]
}

// MARK: - Like Repository

/// いいねのデータアクセス
protocol LikeRepositoryProtocol: Sendable {
    /// いいねする
    func like(postId: UUID) async throws
    /// いいね解除
    func unlike(postId: UUID) async throws
    /// いいね済みか判定
    func isLiked(postId: UUID) async throws -> Bool
}

// MARK: - Comment Repository

/// コメントのデータアクセス
protocol CommentRepositoryProtocol: Sendable {
    /// コメント取得
    func fetchComments(postId: UUID, cursor: Date?, limit: Int) async throws -> [CommentDTO]
    /// コメント投稿
    func insertComment(postId: UUID, content: String, parentId: UUID?) async throws -> CommentDTO
    /// コメント削除
    func deleteComment(id: UUID) async throws
}

/// Supabase `comments` テーブル対応DTO
struct CommentDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    var content: String
    var parentCommentId: UUID?
    let createdAt: Date

    var authorDisplayName: String?
    var authorHandle: String?
    var authorAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case postId = "post_id"
        case userId = "user_id"
        case parentCommentId = "parent_comment_id"
        case createdAt = "created_at"
        case authorDisplayName = "author_display_name"
        case authorHandle = "author_handle"
        case authorAvatarUrl = "author_avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postId = try container.decode(UUID.self, forKey: .postId)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decode(String.self, forKey: .content)
        parentCommentId = try container.decodeIfPresent(UUID.self, forKey: .parentCommentId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
        authorHandle = try container.decodeIfPresent(String.self, forKey: .authorHandle)
        authorAvatarUrl = try container.decodeIfPresent(String.self, forKey: .authorAvatarUrl)
    }
}
