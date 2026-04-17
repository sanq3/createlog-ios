import Foundation
import Supabase
import Storage

// MARK: - Post Repository

final class SupabasePostRepository: PostRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Feed 取得。`author:profiles!posts_user_id_fkey(...)` で投稿者の basic 情報を JOIN で持ち帰る。
    /// Bluesky feed-precache pattern の iOS 版。feed 読み込み 1 回で投稿者 N 人分の basic を SDProfileCache に
    /// 先行書き込みするのに使う。PostDTO.decoder が nested `author` を優先 decode。
    private static let feedSelectClause = "*, author:profiles!posts_user_id_fkey(handle, display_name, avatar_url)"

    func fetchFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [PostDTO] = try await client
                .from("posts")
                .select(Self.feedSelectClause)
                .eq("visibility", value: "public")
                .lt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        } else {
            let result: [PostDTO] = try await client
                .from("posts")
                .select(Self.feedSelectClause)
                .eq("visibility", value: "public")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        }
    }

    /// Discover RPC 呼び出し。server side で「読む意味のある投稿」を絞り込む (media / 200 文字 / リプライ)。
    func fetchDiscoverFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        struct Params: Encodable {
            let page_limit: Int
            let cursor_created_at: String?
        }
        let formatter = ISO8601DateFormatter()
        let params = Params(
            page_limit: limit,
            cursor_created_at: cursor.map { formatter.string(from: $0) }
        )
        let result: [PostDTO] = try await client
            .rpc("get_discover_feed", params: params)
            .execute()
            .value
        return result
    }

    func fetchFollowingFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        // フォロー中ユーザーの投稿はRPC関数で取得
        let session = try await client.auth.session
        let params: [String: String] = [
            "follower_id": session.user.id.uuidString,
            "page_limit": "\(limit)"
        ]
        let result: [PostDTO] = try await client
            .rpc("get_following_feed", params: params)
            .execute()
            .value
        return result
    }

    func fetchUserPosts(userId: UUID, cursor: Date?, limit: Int) async throws -> [PostDTO] {
        let formatter = ISO8601DateFormatter()
        var query = client
            .from("posts")
            .select(Self.feedSelectClause)
            .eq("user_id", value: userId.uuidString)
            .eq("visibility", value: "public")
        if let cursor {
            query = query.lt("created_at", value: formatter.string(from: cursor))
        }
        let result: [PostDTO] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return result
    }

    func insertPost(_ post: PostInsertDTO) async throws -> PostDTO {
        let result: PostDTO = try await client
            .from("posts")
            .insert(post)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func deletePost(id: UUID) async throws {
        try await client
            .from("posts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

extension SupabasePostRepository {
    /// 画像を `post-media` bucket に upload。
    /// path 形式: `{userIdLower}/{ts}_full.jpg` / `{userIdLower}/{ts}_thumb.jpg`
    /// **重要**: `UUID.uuidString` は uppercase だが Storage RLS の `auth.uid()::text` は lowercase。
    /// `.lowercased()` を必ず付ける (avatars bucket で踏んだ過去 bug 防止)。
    func uploadPostMedia(thumbData: Data, fullData: Data, contentType: String, width: Int, height: Int) async throws -> PostMediaItem {
        let session = try await client.auth.session
        let userIdLower = session.user.id.uuidString.lowercased()
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let ext = contentType.contains("png") ? "png" : "jpg"

        let fullPath = "\(userIdLower)/\(ts)_full.\(ext)"
        let thumbPath = "\(userIdLower)/\(ts)_thumb.\(ext)"

        let uploadOptions = FileOptions(contentType: contentType, upsert: false)

        _ = try await client.storage
            .from("post-media")
            .upload(fullPath, data: fullData, options: uploadOptions)

        _ = try await client.storage
            .from("post-media")
            .upload(thumbPath, data: thumbData, options: uploadOptions)

        let fullURL = try client.storage.from("post-media").getPublicURL(path: fullPath)
        let thumbURL = try client.storage.from("post-media").getPublicURL(path: thumbPath)

        return PostMediaItem(
            url: fullURL.absoluteString,
            thumbUrl: thumbURL.absoluteString,
            width: width,
            height: height
        )
    }
}

// MARK: - Follow Repository

final class SupabaseFollowRepository: FollowRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func follow(userId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("follows")
            .insert(["follower_id": session.user.id.uuidString, "following_id": userId.uuidString])
            .execute()
    }

    func unfollow(userId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("follows")
            .delete()
            .eq("follower_id", value: session.user.id.uuidString)
            .eq("following_id", value: userId.uuidString)
            .execute()
    }

    func isFollowing(userId: UUID) async throws -> Bool {
        let session = try await client.auth.session
        let result: [FollowRow] = try await client
            .from("follows")
            .select("id")
            .eq("follower_id", value: session.user.id.uuidString)
            .eq("following_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return !result.isEmpty
    }

    func fetchCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        let followersResponse = try await client
            .from("follows")
            .select("*", head: true, count: .exact)
            .eq("following_id", value: userId.uuidString)
            .execute()

        let followingResponse = try await client
            .from("follows")
            .select("*", head: true, count: .exact)
            .eq("follower_id", value: userId.uuidString)
            .execute()

        return (followersResponse.count ?? 0, followingResponse.count ?? 0)
    }

    /// userId をフォローしているユーザー (= userId の follower) の profile 一覧。
    /// `follows.following_id == userId` を埋め込み profile で返す。
    func fetchFollowers(userId: UUID, limit: Int) async throws -> [ProfileDTO] {
        struct FollowerRow: Decodable {
            let follower: ProfileDTO
            enum CodingKeys: String, CodingKey {
                case follower
            }
        }
        let rows: [FollowerRow] = try await client
            .from("follows")
            .select("follower:profiles!follows_follower_id_fkey(*)")
            .eq("following_id", value: userId.uuidString)
            .limit(limit)
            .execute()
            .value
        return rows.map(\.follower)
    }

    /// userId がフォローしているユーザーの profile 一覧。
    func fetchFollowing(userId: UUID, limit: Int) async throws -> [ProfileDTO] {
        struct FollowingRow: Decodable {
            let following: ProfileDTO
            enum CodingKeys: String, CodingKey {
                case following
            }
        }
        let rows: [FollowingRow] = try await client
            .from("follows")
            .select("following:profiles!follows_following_id_fkey(*)")
            .eq("follower_id", value: userId.uuidString)
            .limit(limit)
            .execute()
            .value
        return rows.map(\.following)
    }
}

private struct FollowRow: Codable {
    let id: UUID
}

// MARK: - Like Repository

final class SupabaseLikeRepository: LikeRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func like(postId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("likes")
            .insert(["user_id": session.user.id.uuidString, "post_id": postId.uuidString])
            .execute()
    }

    func unlike(postId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("likes")
            .delete()
            .eq("user_id", value: session.user.id.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
    }

    func isLiked(postId: UUID) async throws -> Bool {
        let session = try await client.auth.session
        let result: [LikeRow] = try await client
            .from("likes")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("post_id", value: postId.uuidString)
            .limit(1)
            .execute()
            .value
        return !result.isEmpty
    }

    /// 自分がいいねした投稿一覧。`likes` を pivot、`posts` を JOIN、さらに
    /// posts.author を `profiles!posts_user_id_fkey` で JOIN して投稿者 basic も一緒に取る
    /// (Bluesky feed-precache pattern と整合)。並び順は likes.created_at DESC (新しくいいねした順)。
    func fetchLiked(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        let session = try await client.auth.session
        let formatter = ISO8601DateFormatter()

        let selectClause = "created_at, post:posts!likes_post_id_fkey(*, author:profiles!posts_user_id_fkey(handle, display_name, avatar_url))"

        let rows: [LikedPostRow]
        if let cursor {
            rows = try await client
                .from("likes")
                .select(selectClause)
                .eq("user_id", value: session.user.id.uuidString)
                .lt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            rows = try await client
                .from("likes")
                .select(selectClause)
                .eq("user_id", value: session.user.id.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return rows.map(\.post)
    }
}

private struct LikeRow: Codable {
    let id: UUID
}

/// `likes` JOIN `posts` の decode 用。`likes.created_at` は page cursor として
/// ViewModel 側で参照するが、ここでは post embed だけ取り出す。
private struct LikedPostRow: Decodable {
    let post: PostDTO
}

// MARK: - Bookmark Repository

final class SupabaseBookmarkRepository: BookmarkRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func bookmark(postId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("bookmarks")
            .insert(["user_id": session.user.id.uuidString, "post_id": postId.uuidString])
            .execute()
    }

    func unbookmark(postId: UUID) async throws {
        let session = try await client.auth.session
        try await client
            .from("bookmarks")
            .delete()
            .eq("user_id", value: session.user.id.uuidString)
            .eq("post_id", value: postId.uuidString)
            .execute()
    }

    func isBookmarked(postId: UUID) async throws -> Bool {
        let session = try await client.auth.session
        let result: [BookmarkRow] = try await client
            .from("bookmarks")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("post_id", value: postId.uuidString)
            .limit(1)
            .execute()
            .value
        return !result.isEmpty
    }

    /// 自分がブックマークした投稿一覧。`bookmarks` を pivot、`posts` を JOIN。
    /// RLS で自分のみ SELECT 可能なので user_id フィルタは不要だが、明示的に付けて index 利用を促す。
    func fetchBookmarked(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        let session = try await client.auth.session
        let formatter = ISO8601DateFormatter()

        let selectClause = "created_at, post:posts!bookmarks_post_id_fkey(*, author:profiles!posts_user_id_fkey(handle, display_name, avatar_url))"

        let rows: [BookmarkedPostRow]
        if let cursor {
            rows = try await client
                .from("bookmarks")
                .select(selectClause)
                .eq("user_id", value: session.user.id.uuidString)
                .lt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        } else {
            rows = try await client
                .from("bookmarks")
                .select(selectClause)
                .eq("user_id", value: session.user.id.uuidString)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
        }
        return rows.map(\.post)
    }
}

private struct BookmarkRow: Codable {
    let id: UUID
}

private struct BookmarkedPostRow: Decodable {
    let post: PostDTO
}

// MARK: - Comment Repository

final class SupabaseCommentRepository: CommentRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Comment 取得。author basic を JOIN で持ち帰り、SDProfileCache へ先行書き込み可能にする。
    private static let commentSelectClause = "*, author:profiles!comments_user_id_fkey(handle, display_name, avatar_url)"

    func fetchComments(postId: UUID, cursor: Date?, limit: Int) async throws -> [CommentDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [CommentDTO] = try await client
                .from("comments")
                .select(Self.commentSelectClause)
                .eq("post_id", value: postId.uuidString)
                .gt("created_at", value: formatter.string(from: cursor))
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            return result
        } else {
            let result: [CommentDTO] = try await client
                .from("comments")
                .select(Self.commentSelectClause)
                .eq("post_id", value: postId.uuidString)
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            return result
        }
    }

    func insertComment(postId: UUID, content: String, parentId: UUID?) async throws -> CommentDTO {
        var params: [String: String] = [
            "post_id": postId.uuidString,
            "content": content
        ]
        if let parentId {
            params["parent_comment_id"] = parentId.uuidString
        }
        let result: CommentDTO = try await client
            .from("comments")
            .insert(params)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func deleteComment(id: UUID) async throws {
        try await client
            .from("comments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
