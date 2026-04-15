import SwiftUI

struct UserProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var user: User
    @State private var showUnfollowConfirmation = false
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var isBlocked = false
    @State private var blockErrorMessage: String?
    @State private var remotePosts: [Post] = []
    @State private var remoteProjects: [Project] = []
    @State private var weeklyHours: [(day: String, hours: Double)] = []

    init(user: User) {
        _user = State(initialValue: user)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                actionButtons

                // 週間チャート
                WeeklyChart(data: weeklyHours)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                servicesSection
                postsSection
                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("@\(user.handle)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showReportSheet = true
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.triangle")
                    }
                    if isBlocked {
                        Button {
                            Task { await unblock() }
                        } label: {
                            Label("ブロックを解除", systemImage: "slash.circle")
                        }
                    } else {
                        Button(role: .destructive) {
                            showBlockConfirmation = true
                        } label: {
                            Label("ブロックする", systemImage: "slash.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .confirmationDialog(
            "\(user.name)のフォローを解除しますか？",
            isPresented: $showUnfollowConfirmation,
            titleVisibility: .visible
        ) {
            Button("フォロー解除", role: .destructive) {
                toggleFollow()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showBlockConfirmation) {
            BlockConfirmSheet(userName: user.name, userHandle: user.handle) {
                Task { await block() }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(targetName: user.name) { reason, detail in
                Task { await submitReport(reason: reason, detail: detail) }
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { blockErrorMessage != nil },
            set: { if !$0 { blockErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blockErrorMessage ?? "")
        }
        .refreshable {
            // 2026-04-16: 大手 SNS (Instagram/X/Bluesky/Threads) 全社対応の pull-to-refresh。
            // 下にスワイプで最新化。`.task` と同じ loadProfileData を呼び、cache lookup は
            // 既に反映済なので skip して直接 remote refresh 部分だけ実行。
            await loadProfileData(applyCacheFirst: false)
        }
        .task {
            // 初回遷移: cache 即反映 → 並列 remote fetch で完全情報に差し替え
            await loadProfileData(applyCacheFirst: true)
        }
    }

    /// profile + 周辺データ (posts / apps / weekly / isFollowing / isBlocked) を並列取得して View state を更新。
    /// - `applyCacheFirst: true` (初回遷移時): SDProfileCache から basic を同期反映してから remote fetch
    /// - `applyCacheFirst: false` (pull-to-refresh): 画面を残したまま直接 remote fetch のみ
    private func loadProfileData(applyCacheFirst: Bool) async {
        if applyCacheFirst, let cached = dependencies.profileRepository.cachedProfile(userId: user.id) {
            let wasFollowing = user.isFollowing
            user = User(from: cached)
            user.isFollowing = wasFollowing
        }
        async let profileDTO = try? await dependencies.profileRepository.fetchProfile(userId: user.id)
        async let blockedCheck = (try? await dependencies.ugcRepository.isBlocked(userId: user.id)) ?? false
        async let postsDTO = (try? await dependencies.postRepository.fetchUserPosts(userId: user.id, cursor: nil, limit: 20)) ?? []
        async let appsDTO = (try? await dependencies.appRepository.fetchApps(userId: user.id)) ?? []
        async let weeklyStats = try? await dependencies.statsRepository.fetchWeeklyStats(containing: Date())
        async let followingState = (try? await dependencies.followRepository.isFollowing(userId: user.id)) ?? false
        let (fullProfile, blocked, posts, apps, weekly, following) = await (profileDTO, blockedCheck, postsDTO, appsDTO, weeklyStats, followingState)
        if let fullProfile {
            user = User(from: fullProfile)
        }
        isBlocked = blocked
        remotePosts = posts.map { Post(from: $0) }
        remoteProjects = apps.map { Project(from: $0) }
        weeklyHours = Self.buildWeeklyHours(from: weekly)
        user.isFollowing = following
    }

    /// WeeklyStats を WeeklyChart 用に曜日ラベル付き配列に変換。
    /// ProfileViewModel.buildWeeklyHours と同ロジック。
    private static func buildWeeklyHours(from weekly: WeeklyStats?) -> [(day: String, hours: Double)] {
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        guard let weekly else {
            return labels.map { ($0, 0) }
        }
        let sorted = weekly.dailyTotals.sorted { $0.date < $1.date }
        return sorted.enumerated().map { idx, stats in
            let label = idx < labels.count ? labels[idx] : ""
            return (label, Double(stats.totalMinutes) / 60.0)
        }
    }

    // MARK: - Follow

    /// optimistic UI でフォロー/解除し、失敗時は rollback。
    /// FollowListView.toggleFollow と同じ pattern。
    private func toggleFollow() {
        let wasFollowing = user.isFollowing
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            user.isFollowing.toggle()
        }
        HapticManager.light()

        Task {
            do {
                if wasFollowing {
                    try await dependencies.followRepository.unfollow(userId: user.id)
                } else {
                    try await dependencies.followRepository.follow(userId: user.id)
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        user.isFollowing = wasFollowing
                    }
                }
            }
        }
    }

    // MARK: - Block / Unblock / Report

    private func block() async {
        do {
            try await dependencies.ugcRepository.blockUser(userId: user.id)
            isBlocked = true
            HapticManager.success()
            // ブロック後は画面を閉じる (フィードからこのユーザーを見えなくする前提)
            dismiss()
        } catch {
            blockErrorMessage = "ブロックに失敗しました。しばらくしてから再試行してください。"
        }
    }

    private func unblock() async {
        do {
            try await dependencies.ugcRepository.unblockUser(userId: user.id)
            isBlocked = false
            HapticManager.success()
        } catch {
            blockErrorMessage = "ブロック解除に失敗しました。"
        }
    }

    private func submitReport(reason: ReportReason, detail: String) async {
        do {
            try await dependencies.ugcRepository.reportContent(
                targetId: user.id,
                targetType: "user",
                reason: reason.rawValue,
                detail: detail.isEmpty ? nil : detail
            )
        } catch {
            // ReportSheet は submit 直後に success 画面を出す (UX 先行)。
            // 失敗時のリトライ導線は将来検討。今はログのみで swallow。
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AvatarView(
                    initials: user.initials,
                    size: 86,
                    status: user.status,
                    imageURL: user.avatarUrl.flatMap(URL.init(string:))
                )

                Spacer()

                HStack(spacing: 0) {
                    profileStat(value: "\(remotePosts.count)", label: "投稿")
                    Spacer()
                    profileStat(value: "\(user.followerCount)", label: "フォロワー")
                    Spacer()
                    profileStat(value: "\(user.followingCount)", label: "フォロー中")
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextPrimary)

                if !user.occupation.isEmpty {
                    Text("\(user.occupation) / \(user.experienceLevel.label)")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                }

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.top, 2)
                }

                Text("累計 \(Int(user.totalHours))h")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                if user.isFollowing {
                    showUnfollowConfirmation = true
                } else {
                    toggleFollow()
                }
            } label: {
                Text(user.isFollowing ? "フォロー中" : "フォローする")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(user.isFollowing ? Color.clTextPrimary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        user.isFollowing ? Color.clSurfaceLow : Color.clAccent,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                user.isFollowing ? Color.clBorder : Color.clear,
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)

        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Services (vertical list with reviews)

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("マイプロダクト")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .padding(.horizontal, 16)

            if remoteProjects.isEmpty {
                Text("マイプロダクトはまだ登録されていません")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(remoteProjects) { project in
                    serviceCard(project: project)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Posts

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                if remotePosts.isEmpty {
                    Text("まだ投稿がありません")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                        .padding(.horizontal, 16)
                } else {
                    ForEach(remotePosts) { post in
                        PostCardView(post: post)
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
                .tabularNumbers()
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.clTextSecondary)
        }
    }

    private func serviceCard(project: Project) -> some View {
        let iconColor = Color(
            red: project.iconColor.red,
            green: project.iconColor.green,
            blue: project.iconColor.blue
        )

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [iconColor, iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(project.iconInitials)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(project.name)
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextPrimary)

                    Spacer()

                    if project.reviewCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.clAccent)
                            Text(String(format: "%.1f", project.averageRating))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary)
                            Text("(\(project.reviewCount))")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.clTextTertiary)
                        }
                    }
                }

                Text(project.description)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
