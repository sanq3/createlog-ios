import SwiftUI

struct PostDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @State var post: Post
    @State private var comments: [Comment] = []
    @State private var commentText = ""
    @State private var heartScale: CGFloat = 1.0
    @FocusState private var isCommentFocused: Bool
    @State private var showReport = false
    @State private var showBlock = false
    @State private var myInitials: String = "?"
    @State private var myAvatarUrl: String?
    /// 投稿者の userId (ブロック操作用)。PostDTO から引いて保持。
    @State private var authorUserId: UUID?
    /// 返信モード: 誰に返信しているかを保持。`nil` の時は通常のコメント投稿。
    /// 1 階層のみの制約 (X / Instagram 同様): 返信の返信は元の親 comment に紐づけ、
    /// UI では `@handle に返信` と示すだけで DB 的にはフラット化する。
    @State private var replyingTo: ReplyTarget?

    private struct ReplyTarget: Equatable {
        /// DB 挿入時に `parent_comment_id` として使う UUID (常に**最上位の親** comment)。
        let parentId: UUID
        let handle: String
        let authorName: String
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    postHeader
                    postBody
                    mediaSection
                    timestampRow
                    statsRow
                    Divider().foregroundStyle(Color.clBorder).padding(.horizontal, 16)
                    actionBar
                    Divider().foregroundStyle(Color.clBorder).padding(.horizontal, 16)
                    commentsSection
                }
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)

            commentInputBar
        }
        .background(Color.clBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("post.title")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showReport = true
                    } label: {
                        Label("report.action", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) {
                        showBlock = true
                    } label: {
                        Label("profile.block", systemImage: "nosign")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextTertiary)
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(targetName: post.name) { reason, detail in
                Task {
                    try? await dependencies.ugcRepository.reportContent(
                        targetId: post.id,
                        targetType: "post",
                        reason: reason.code,
                        detail: detail.isEmpty ? nil : detail
                    )
                }
            }
        }
        .sheet(isPresented: $showBlock) {
            BlockConfirmSheet(
                userName: post.name,
                userHandle: post.handle,
                onBlock: {
                    guard let uid = authorUserId ?? post.userId else { return }
                    Task {
                        try? await dependencies.ugcRepository.blockUser(userId: uid)
                    }
                }
            )
        }
        .task {
            await loadInitial()
            // 2026-04-20: DomainEvent subscribe。View lifecycle で .task 終了時に stream も終わる。
            // 他 VM (FeedViewModel / ComposeViewModel 等) からの like/comment/delete 変更を受けて
            // この画面の post/comments を in-place patch する。
            await subscribeToEvents()
        }
    }

    // MARK: - Event subscription (2026-04-20)

    /// 他 VM からの DomainEvent を受けて自 state を patch。
    /// 自分自身が publish した event も同 stream に来るが、idempotent な処理で副作用を出さない。
    private func subscribeToEvents() async {
        for await event in dependencies.domainEventBus.events() {
            switch event {
            case .likeToggled(let postId, let liked, let count) where postId == post.id:
                // Feed で like → ここも同期。自身 toggleLike からの publish は同値 set で no-op。
                if post.isLiked != liked { post.isLiked = liked }
                if post.likes != count { post.likes = count }

            case .commentDeleted(let postId, let commentId) where postId == post.id:
                // 親 comment 削除
                comments.removeAll(where: { $0.id == commentId })
                // 返信 comment 削除 (parent.replies から除く)
                comments = comments.map { parent in
                    guard parent.replies.contains(where: { $0.id == commentId }) else { return parent }
                    return Comment(
                        id: parent.id,
                        authorName: parent.authorName,
                        authorHandle: parent.authorHandle,
                        authorInitials: parent.authorInitials,
                        authorAvatarUrl: parent.authorAvatarUrl,
                        text: parent.text,
                        timestamp: parent.timestamp,
                        likes: parent.likes,
                        isLiked: parent.isLiked,
                        replies: parent.replies.filter { $0.id != commentId }
                    )
                }
                post.comments = max(0, post.comments - 1)

            case .postDeleted(let postId) where postId == post.id:
                // 自分が開いている投稿自体が削除された → Navigation pop は View 側の dismiss で対応、
                // v2.0 では @Environment(\.dismiss) を持ってないので no-op (navigation pop は呼出側の責務)。
                // 代わりに comments を空にして UI 的に「消失」を示唆する。
                comments = []

            case .blockToggled(let targetUserId, let blocked) where blocked && targetUserId == post.userId:
                // 自分が開いている投稿の投稿者をブロックした → comments 消して pop 期待 (View 側で上位 dismiss)
                comments = []

            case .profileUpdated(let userId, let name, let handle, let avatarUrl, _) where userId == post.userId:
                // 投稿者プロフィール更新 → 表示 author 情報を in-place patch。
                // avatarUrl: nil = 未変更と解釈、old を維持 (X 等大手 SNS は avatar 削除機能無し)。
                post = Post(
                    id: post.id,
                    userId: post.userId,
                    name: name,
                    handle: handle,
                    status: post.status,
                    createdAt: post.createdAt,
                    workMinutes: post.workMinutes,
                    content: post.content,
                    likes: post.likes,
                    reposts: post.reposts,
                    comments: post.comments,
                    media: post.media,
                    authorAvatarUrl: avatarUrl ?? post.authorAvatarUrl
                )

            default:
                break
            }
        }
    }

    // MARK: - Loading

    /// 自分のプロフィール (コメント入力欄のアバター用) と投稿のコメント一覧を並列ロード。
    private func loadInitial() async {
        // async let は nonisolated な子 task を spawn するため、main-actor @State `post` に
        // 直接触れない。Sendable な値 (UUID/Bool) を事前キャプチャして渡す。
        let capturedPostId = post.id
        let capturedIsLiked = post.isLiked
        async let profile: ProfileDTO? = (try? await dependencies.profileRepository.fetchMyProfile())
        async let commentDTOs: [CommentDTO] = (try? await dependencies.commentRepository.fetchComments(
            postId: capturedPostId,
            cursor: nil,
            limit: 50
        )) ?? []
        async let likedState: Bool = (try? await dependencies.likeRepository.isLiked(postId: capturedPostId)) ?? capturedIsLiked

        let (myProfile, dtos, liked) = await (profile, commentDTOs, likedState)

        if let myProfile {
            let name = myProfile.displayName ?? myProfile.handle ?? ""
            myInitials = name.isEmpty ? "?" : String(name.prefix(1))
            myAvatarUrl = myProfile.avatarUrl
        }

        authorUserId = post.userId
        post.isLiked = liked
        comments = buildComments(from: dtos)
    }

    private func commentFromDTO(_ dto: CommentDTO, replies: [Comment] = []) -> Comment {
        let displayName = dto.authorDisplayName ?? dto.authorHandle ?? ""
        let initials = displayName.isEmpty ? "?" : String(displayName.prefix(1))
        return Comment(
            id: dto.id,
            authorName: displayName,
            authorHandle: dto.authorHandle ?? "",
            authorInitials: initials,
            authorAvatarUrl: dto.authorAvatarUrl,
            text: dto.content,
            timestamp: dto.createdAt,
            replies: replies
        )
    }

    /// Flat な [CommentDTO] を parent/reply 2 階層に再構成する。
    /// - 親 (`parent_comment_id == nil`): 新しい順
    /// - 返信 (`parent_comment_id != nil`): 古い順 (会話の流れ保持)
    /// 1 階層制約: 返信の返信も DB 上は同じ parent に紐づくので自動的に 2 階層に収まる。
    private func buildComments(from dtos: [CommentDTO]) -> [Comment] {
        let repliesByParent = Dictionary(
            grouping: dtos.filter { $0.parentCommentId != nil },
            by: { $0.parentCommentId! }
        )
        let parents = dtos
            .filter { $0.parentCommentId == nil }
            .sorted { $0.createdAt > $1.createdAt }
        return parents.map { parentDTO in
            let childDTOs = (repliesByParent[parentDTO.id] ?? [])
                .sorted { $0.createdAt < $1.createdAt }
            let children = childDTOs.map { commentFromDTO($0) }
            return commentFromDTO(parentDTO, replies: children)
        }
    }

    private func toggleLike() {
        let wasLiked = post.isLiked
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
            post.isLiked.toggle()
            post.likes += post.isLiked ? 1 : -1
            heartScale = 1.4
        }
        HapticManager.light()
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(duration: 0.3)) {
                heartScale = 1.0
            }
        }
        Task {
            do {
                if wasLiked {
                    try await dependencies.likeRepository.unlike(postId: post.id)
                } else {
                    try await dependencies.likeRepository.like(postId: post.id)
                }
                // 成功確定 → Feed 等にも like state 反映。自身も subscribe 経路で受けるが
                // idempotent (同値 set で no-op) なので副作用なし。
                await MainActor.run {
                    dependencies.domainEventBus.publish(.likeToggled(
                        postId: post.id,
                        liked: post.isLiked,
                        count: post.likes
                    ))
                }
            } catch {
                // rollback
                await MainActor.run {
                    withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                        post.isLiked = wasLiked
                        post.likes += wasLiked ? 1 : -1
                    }
                }
            }
        }
    }

    private func submitComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        HapticManager.light()
        let draftText = text
        let target = replyingTo
        commentText = ""
        replyingTo = nil
        isCommentFocused = false
        Task {
            do {
                let dto = try await dependencies.commentRepository.insertComment(
                    postId: post.id,
                    content: draftText,
                    parentId: target?.parentId
                )
                await MainActor.run {
                    appendComment(dto)
                    post.comments += 1
                    // Feed 等に broadcast (post.comments count 更新のため)。
                    // comment 本体は既に appendComment で反映済、受け手側は !contains(id) で重複回避。
                    let newComment = commentFromDTO(dto)
                    dependencies.domainEventBus.publish(.commentAdded(
                        postId: post.id,
                        comment: newComment
                    ))
                }
            } catch {
                // 失敗時は入力と返信モードを復元
                await MainActor.run {
                    commentText = draftText
                    replyingTo = target
                }
            }
        }
    }

    /// 新規コメント / 返信を受け取って既存リストに挿入する。
    /// 親コメント: 新しい順の先頭に追加。
    /// 返信: 該当親の `replies` 末尾に追加 (古い順のため新しいものは最後)。
    private func appendComment(_ dto: CommentDTO) {
        let newComment = commentFromDTO(dto)
        if let parentId = dto.parentCommentId {
            comments = comments.map { parent in
                guard parent.id == parentId else { return parent }
                return Comment(
                    id: parent.id,
                    authorName: parent.authorName,
                    authorHandle: parent.authorHandle,
                    authorInitials: parent.authorInitials,
                    authorAvatarUrl: parent.authorAvatarUrl,
                    text: parent.text,
                    timestamp: parent.timestamp,
                    likes: parent.likes,
                    isLiked: parent.isLiked,
                    replies: parent.replies + [newComment]
                )
            }
        } else {
            comments.insert(newComment, at: 0)
        }
    }

    // MARK: - Post Header

    private var postHeader: some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: post.initials,
                size: 48,
                status: post.status,
                imageURL: post.authorAvatarUrl.flatMap(URL.init(string:))
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(post.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                Text("@\(post.handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Post Body

    private var postBody: some View {
        Text(post.content)
            .font(.system(size: 17))
            .foregroundStyle(Color.clTextPrimary)
            .lineSpacing(6)
            .padding(.horizontal, 16)
            .padding(.top, 14)
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        if let media = post.media {
            Group {
                switch media {
                case .images(let images):
                    imageGrid(images)
                case .video(let video):
                    videoThumbnail(video)
                case .code(let code):
                    codeBlock(code)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func imageGrid(_ images: [PostImage]) -> some View {
        PostImageGrid(images: images)
    }

    private func videoThumbnail(_ video: PostVideo) -> some View {
        PostVideoThumbnail(video: video)
    }

    private func codeBlock(_ code: PostCode) -> some View {
        PostCodeBlock(code: code)
    }

    // MARK: - Timestamp

    private var timestampRow: some View {
        Text("14:30 \u{30FB} 2026\u{5E74}3\u{6708}28\u{65E5}")
            .font(.system(size: 14))
            .foregroundStyle(Color.clTextTertiary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 20) {
            statItem(count: post.reposts, label: "post.repost.action")
            statItem(count: post.likes, label: "post.like.action")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func statItem(count: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Spacer()

            // コメントボタン: 入力欄にフォーカスする
            Button {
                HapticManager.light()
                isCommentFocused = true
            } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                toggleLike()
            } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .scaleEffect(heartScale)
                    .foregroundStyle(post.isLiked ? Color.clError : Color.clTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            ShareLink(item: URL(string: "https://createlog.app/post/\(post.id)")!) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 6)
    }

    /// 現状未使用 (repost は MVP 対象外)。v2.1 の repost 実装時に復活予定。
    private func actionButton(icon: String, count: Int) -> some View {
        Button {
            HapticManager.light()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.clTextTertiary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comments

    private var commentsSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(comments) { comment in
                commentRow(comment)
                ForEach(comment.replies) { reply in
                    // 返信の返信も最上位の親 (comment.id) に紐づけ (1 階層制約)
                    replyRow(reply, parentCommentId: comment.id)
                }
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(
                    initials: comment.authorInitials,
                    size: 36,
                    imageURL: comment.authorAvatarUrl.flatMap(URL.init(string:))
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(comment.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(comment.authorHandle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Text(comment.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineSpacing(4)

                    commentMeta(comment) {
                        // 親コメントへ返信: parentId = このコメント自身の id
                        startReply(to: comment, parentId: comment.id)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().foregroundStyle(Color.clBorder).padding(.leading, 62)
        }
    }

    private func replyRow(_ reply: Comment, parentCommentId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(
                    initials: reply.authorInitials,
                    size: 36,
                    imageURL: reply.authorAvatarUrl.flatMap(URL.init(string:))
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(reply.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(reply.authorHandle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Text(reply.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineSpacing(4)

                    commentMeta(reply) {
                        // 返信への返信も最上位の parent に紐づく (1 階層制約)
                        startReply(to: reply, parentId: parentCommentId)
                    }
                }
            }
            .padding(.leading, 40)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(width: 2)
                    .padding(.leading, 34)
                    .padding(.vertical, 4)
            }

            Divider().foregroundStyle(Color.clBorder).padding(.leading, 62)
        }
    }

    private func commentMeta(_ comment: Comment, onReply: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Text(relativeTime(from: comment.timestamp))
                .font(.system(size: 12))
                .foregroundStyle(Color.clTextTertiary)

            if comment.likes > 0 {
                Text("post.likes \(comment.likes)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Button(action: onReply) {
                Text("compose.reply")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    /// 返信モードを開始。入力欄の focus と replyingTo state を同時に更新。
    private func startReply(to target: Comment, parentId: UUID) {
        HapticManager.light()
        replyingTo = ReplyTarget(
            parentId: parentId,
            handle: target.authorHandle,
            authorName: target.authorName
        )
        isCommentFocused = true
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider().foregroundStyle(Color.clBorder)

            if let target = replyingTo {
                HStack {
                    Text("compose.reply.replyingTo \(target.handle)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.clAccent)
                    Spacer()
                    Button {
                        HapticManager.light()
                        replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.clAccent.opacity(0.08))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 10) {
                AvatarView(
                    initials: myInitials,
                    size: 32,
                    status: .offline,
                    imageURL: myAvatarUrl.flatMap(URL.init(string:))
                )

                TextField(
                    replyingTo.map { "@\($0.handle) に返信..." } ?? "コメントを追加...",
                    text: $commentText
                )
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
                    .focused($isCommentFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.clSurfaceHigh)
                    )

                if !commentText.isEmpty {
                    Button {
                        submitComment()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.clAccent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: commentText.isEmpty)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: replyingTo)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        RelativeTimeFormatter.format(from: date)
    }
}
