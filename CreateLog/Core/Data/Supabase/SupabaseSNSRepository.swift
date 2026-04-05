import Foundation
import Supabase

// MARK: - Post Repository

final class SupabasePostRepository: PostRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [PostDTO] = try await client
                .from("posts")
                .select()
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
                .select()
                .eq("visibility", value: "public")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return result
        }
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
}

private struct LikeRow: Codable {
    let id: UUID
}

// MARK: - Comment Repository

final class SupabaseCommentRepository: CommentRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchComments(postId: UUID, cursor: Date?, limit: Int) async throws -> [CommentDTO] {
        let formatter = ISO8601DateFormatter()
        if let cursor {
            let result: [CommentDTO] = try await client
                .from("comments")
                .select()
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
                .select()
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
