import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    /// オンボーディングで作成したローカル SDProject。remote (apps) に同期済 (remoteAppId != nil)
    /// は ProfileViewModel.apps 経由で出るので除外し、二重表示を防ぐ。
    @Query(
        filter: #Predicate<SDProject> { $0.remoteAppId == nil },
        sort: \SDProject.createdAt,
        order: .reverse
    )
    private var localProjects: [SDProject]
    /// 2026-04-20: MainTabView @State から inject される。tab 切替で identity 破壊されない。
    /// 以前は init(dependencies:) 内で @State 初期値として VM を作っていたが、
    /// switch selectedTab branch 変化で init が再実行され、scroll position や
    /// fetched profile cache がリセットされていた。
    @Bindable var viewModel: ProfileViewModel
    @State private var showShareSheet = false
    @State private var showEditProfile = false
    /// 自分のプロフィールでのみ表示するタブ (投稿 / いいね / ブックマーク)。
    /// 他人のプロフィールは UserProfileView (別 View) でタブなし、投稿のみ表示。
    @State private var selectedPostTab: PostTab = .posts

    private enum PostTab: String, CaseIterable {
        case posts = "投稿"
        case likes = "いいね"
        case bookmarks = "ブックマーク"
    }

    /// profile 未 load (cold cache 初回) の場合は空文字 User を返し、body 側で `.redacted(.placeholder)`
    /// で skeleton として描画する。通常は cache hit で cold cache は初回 login 直後のみ。
    private var user: User {
        if let dto = viewModel.profile {
            return User(from: dto)
        }
        return User(name: "", handle: "")
    }
    private var userPosts: [Post] {
        viewModel.posts.map { Post(from: $0) }
    }
    /// Remote Supabase に保存されたアプリ (apps テーブル)。
    /// local SDProject (@Query) はオンボーディング登録分。両方並べて表示する。
    private var userProjects: [Project] {
        viewModel.apps.map { Project(from: $0) }
    }
    private var weeklyHours: [(String, Double)] {
        viewModel.weeklyHours
    }
    /// SWR: profile が未 load の初回のみ skeleton 表示。cache hit 時は即座に実データ。
    private var isColdCache: Bool {
        viewModel.profile == nil
    }

    private var handle: String { "@\(user.handle)" }
    private var profileURL: String { "https://createlog.app/\(user.handle)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header row: Avatar + Stats
                HStack(spacing: 0) {
                    AvatarView(
                        initials: user.initials,
                        size: 86,
                        status: .offline,
                        imageURL: user.avatarUrl.flatMap(URL.init(string:))
                    )

                    Spacer()

                    HStack(spacing: 0) {
                        profileStat(value: "\(userPosts.count)", label: "post.title")
                        Spacer()
                        NavigationLink {
                            FollowListView(initialTab: .followers)
                        } label: {
                            profileStat(value: "\(user.followerCount)", label: "profile.followers")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        NavigationLink {
                            FollowListView(initialTab: .following)
                        } label: {
                            profileStat(value: "\(user.followingCount)", label: "profile.following")
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

                // Name + Occupation + Bio
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextPrimary)

                    // 職業 + 経験年数
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

                    Text("recording.total.hours \(Int(user.totalHours))")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                        .padding(.top, 2)

                    // 外部リンク
                    if !user.links.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(user.links) { link in
                                HStack(spacing: 4) {
                                    Image(systemName: link.type.iconName)
                                        .font(.system(size: 12))
                                    Text(link.label)
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(Color.clAccent)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Action buttons
                HStack(spacing: 6) {
                    Button { showEditProfile = true } label: {
                        Text("profile.edit")
                            .profileActionButton()
                    }

                    Button {
                        UIPasteboard.general.string = handle
                        HapticManager.light()
                        showShareSheet = true
                    } label: {
                        Text("profile.share")
                            .profileActionButton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)

                // Mini chart
                WeeklyChart(data: weeklyHours)
                    .padding(.horizontal, 16)

                // マイプロダクト (ローカル SDProject + リモート Project)
                VStack(alignment: .leading, spacing: 12) {
                    Text("profile.myProducts")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 16)

                    // ローカル (オンボーディングで登録した SDProject)
                    ForEach(localProjects) { project in
                        localProjectCard(project: project)
                    }

                    // リモート (Supabase から取得した Project)
                    ForEach(userProjects) { project in
                        serviceCard(project: project)
                    }
                }
                .padding(.top, 20)

                // 投稿セクション (自分のプロフィールのみタブ表示)
                // 他人のプロフィール = UserProfileView がタブなし投稿のみ表示する別実装。
                VStack(spacing: 0) {
                    // タブバー (投稿 / いいね / ブックマーク)
                    HStack(spacing: 0) {
                        ForEach(PostTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                    selectedPostTab = tab
                                }
                                HapticManager.selection()
                                Task { await loadSelectedTabIfNeeded(tab) }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: selectedPostTab == tab ? .semibold : .regular))
                                        .foregroundStyle(
                                            selectedPostTab == tab ? Color.clTextPrimary : Color.clTextTertiary
                                        )
                                    Rectangle()
                                        .fill(selectedPostTab == tab ? Color.clAccent : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)

                    Divider()
                        .foregroundStyle(Color.clBorder)

                    tabContentSection
                }
                .padding(.top, 20)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle(handle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView(
                user: user,
                profileRepository: deps.profileRepository,
                eventBus: deps.domainEventBus,
                domainContext: deps.domainContext
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ProfileShareSheet(
                name: user.name,
                handle: handle,
                profileURL: profileURL,
                initials: user.initials,
                avatarUrl: user.avatarUrl
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .redacted(reason: isColdCache ? .placeholder : [])
        .refreshable {
            await viewModel.loadProfile()
        }
        .task {
            // ViewModel.init で SDProfileCache から同期 fetch 済 → body 初回描画時に既に
            // profile が埋まっている (cache hit 時)。ここでは background revalidate のみ。
            await viewModel.loadProfile()
            // Onboarding 時に sync 失敗した SDProject (remoteAppId==nil) を救済 sync。
            // Discover フィードに表示されるようにする。冪等なので毎回 Profile 開く度に実行しても安全。
            await viewModel.syncUnsyncedProjectsIfNeeded(modelContext: modelContext)
        }
    }

    @ViewBuilder
    private var tabContentSection: some View {
        switch selectedPostTab {
        case .posts:
            postsListSection(
                items: userPosts,
                emptyMessage: "まだ投稿がありません"
            )
        case .likes:
            likedListSection
        case .bookmarks:
            bookmarkedListSection
        }
    }

    @ViewBuilder
    private func postsListSection(items: [Post], emptyMessage: String) -> some View {
        if items.isEmpty {
            Text(emptyMessage)
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { post in
                    PostCardView(post: post)
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var likedListSection: some View {
        if viewModel.isLoadingLiked && viewModel.likedPosts.isEmpty {
            ProgressView()
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else if viewModel.likedPosts.isEmpty {
            Text("post.empty.liked")
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.likedPosts, id: \.id) { dto in
                    // 初期値は「自分がいいねした投稿」なので isLiked = true。unlike 時に親に通知して
                    // リストから除外する。
                    var post = Post(from: dto)
                    let _ = (post.isLiked = true)
                    PostCardView(
                        post: post,
                        onLikeChanged: { newLiked in
                            if !newLiked {
                                viewModel.removeLikedPost(id: dto.id)
                            }
                        }
                    )
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var bookmarkedListSection: some View {
        if viewModel.isLoadingBookmarked && viewModel.bookmarkedPosts.isEmpty {
            ProgressView()
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else if viewModel.bookmarkedPosts.isEmpty {
            Text("post.empty.bookmarked")
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.bookmarkedPosts, id: \.id) { dto in
                    var post = Post(from: dto)
                    let _ = (post.isBookmarked = true)
                    PostCardView(
                        post: post,
                        onBookmarkChanged: { newBookmarked in
                            if !newBookmarked {
                                viewModel.removeBookmarkedPost(id: dto.id)
                            }
                        }
                    )
                }
            }
            .padding(.top, 12)
        }
    }

    private func loadSelectedTabIfNeeded(_ tab: PostTab) async {
        switch tab {
        case .posts:
            break  // 投稿は loadProfile() で fetch 済
        case .likes:
            await viewModel.loadLikedPosts()
        case .bookmarks:
            await viewModel.loadBookmarkedPosts()
        }
    }

    private func profileStat(value: String, label: LocalizedStringKey) -> some View {
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

    private func localProjectCard(project: SDProject) -> some View {
        let primaryURL = nonEmptyURL(project.storeURL) ?? nonEmptyURL(project.githubURL)

        return NavigationLink {
            SDProjectDetailView(project: project)
        } label: {
            HStack(spacing: 12) {
                Button {
                    openExternal(primaryURL)
                } label: {
                    projectIcon(project: project)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Button {
                            openExternal(primaryURL)
                        } label: {
                            Text(project.name)
                                .font(.clHeadline)
                                .foregroundStyle(Color.clTextPrimary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)

                        statusBadge(for: project.status)

                        if !project.platforms.isEmpty {
                            Text(project.platforms.joined(separator: " · "))
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer(minLength: 8)

                        ratingChip(average: nil, count: 0)
                            .layoutPriority(1)
                    }

                    if !project.appDescription.isEmpty {
                        Text(project.appDescription)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func openExternal(_ url: URL?) {
        guard let url else { return }
        openURL(url)
        HapticManager.light()
    }

    private func nonEmptyURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty, let url = URL(string: raw) else { return nil }
        return url
    }

    @ViewBuilder
    private func ratingChip(average: Double?, count: Int) -> some View {
        if let average, count > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.clAccent)
                Text(String(format: "%.1f", average))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.clTextTertiary)
            }
        } else {
            Text("rating.unrated")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    /// アイコン表示。優先順:
    /// 1. iconImageData (PhotosPicker でローカル選択した生画像)
    /// 2. remoteIconUrl (同期成功後に保存される Storage URL — sync 後 instant 反映)
    /// 3. iconColor + 頭文字 gradient fallback
    @ViewBuilder
    private func projectIcon(project: SDProject) -> some View {
        if let data = project.iconImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if let urlString = project.remoteIconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    iconGradientFallback(project: project)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            iconGradientFallback(project: project)
        }
    }

    private func iconGradientFallback(project: SDProject) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [project.iconColor, project.iconColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(project.name.prefix(1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            )
    }

    private func statusBadge(for status: ProjectStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusBadgeForeground(status))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(statusBadgeBackground(status), in: Capsule())
    }

    private func statusBadgeForeground(_ status: ProjectStatus) -> Color {
        switch status {
        case .draft: Color.clTextSecondary
        case .published: Color.clAccent
        case .archived: Color.clTextTertiary
        }
    }

    private func statusBadgeBackground(_ status: ProjectStatus) -> Color {
        switch status {
        case .draft: Color.clSurfaceHigh
        case .published: Color.clAccent.opacity(0.12)
        case .archived: Color.clSurfaceHigh.opacity(0.6)
        }
    }

    private func serviceCard(project: Project) -> some View {
        let iconColor = Color(
            red: project.iconColor.red,
            green: project.iconColor.green,
            blue: project.iconColor.blue
        )
        let primaryURL = nonEmptyURL(project.storeURL) ?? nonEmptyURL(project.githubURL)

        return NavigationLink {
            ProjectDetailView(project: project)
        } label: {
            HStack(spacing: 12) {
                Button {
                    openExternal(primaryURL)
                } label: {
                    remoteProjectIcon(project: project, iconColor: iconColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Button {
                            openExternal(primaryURL)
                        } label: {
                            Text(project.name)
                                .font(.clHeadline)
                                .foregroundStyle(Color.clTextPrimary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)

                        statusBadge(for: project.status)

                        Text(project.platform.rawValue)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        ratingChip(average: project.averageRating, count: project.reviewCount)
                            .layoutPriority(1)
                    }

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func remoteProjectIcon(project: Project, iconColor: Color) -> some View {
        if let urlString = project.iconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    remoteIconFallback(project: project, iconColor: iconColor)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            remoteIconFallback(project: project, iconColor: iconColor)
        }
    }

    private func remoteIconFallback(project: Project, iconColor: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
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
    }
}

// MARK: - Share Sheet (BeReal style)

struct ProfileShareSheet: View {
    let name: String
    let handle: String
    let profileURL: String
    let initials: String
    var avatarUrl: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false
    @State private var cardAppeared = false
    @State private var iconsAppeared = false
    @State private var showScanner = false

    private let avatarSize: CGFloat = 100
    private let cardCornerRadius: CGFloat = 28

    private var isDark: Bool { colorScheme == .dark }

    private var backgroundColors: [Color] {
        isDark
            ? [Color(white: 0.18), Color(white: 0.12), Color(white: 0.15)]
            : [Color(white: 0.92), Color(white: 0.88), Color(white: 0.90)]
    }

    private var cardBackground: Color {
        isDark ? .white : .white
    }

    private var cardTextColor: Color {
        .black
    }

    private var cardHandleColor: Color {
        Color(white: 0.5)
    }

    private var overlayButtonBg: Color {
        isDark ? .white.opacity(0.15) : .black.opacity(0.08)
    }

    private var overlayIconColor: Color {
        isDark ? .white : .black
    }

    private var bottomTextColor: Color {
        isDark ? .white : Color(white: 0.25)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(overlayIconColor)
                            .frame(width: 40, height: 40)
                            .background(overlayButtonBg, in: Circle())
                    }

                    Spacer()

                    Button { showScanner = true } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(overlayIconColor)
                            .frame(width: 40, height: 40)
                            .background(overlayButtonBg, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // Card with avatar overlapping top edge
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: avatarSize / 2 + 12)

                        Text(name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(cardTextColor)
                            .padding(.bottom, 4)

                        Text(handle)
                            .font(.system(size: 15))
                            .foregroundStyle(cardHandleColor)
                            .padding(.bottom, 24)

                        if let qrImage = generateQRCode(from: profileURL) {
                            ZStack {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)

                                Text("CL")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(.black, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        Spacer().frame(height: 32)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        cardBackground,
                        in: RoundedRectangle(cornerRadius: cardCornerRadius)
                    )
                    .shadow(color: .black.opacity(isDark ? 0.4 : 0.12), radius: 24, y: 8)
                    .padding(.horizontal, 28)
                    .padding(.top, avatarSize / 2)

                    AvatarView(
                        initials: initials,
                        size: avatarSize,
                        status: .offline,
                        imageURL: avatarUrl.flatMap(URL.init(string:))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(cardBackground, lineWidth: 4)
                            .frame(width: avatarSize, height: avatarSize)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .scaleEffect(cardAppeared ? 1 : 0.85)
                .opacity(cardAppeared ? 1 : 0)
                .rotation3DEffect(
                    .degrees(cardAppeared ? 0 : 8),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )

                Spacer()

                if copied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("common.copied")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(bottomTextColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(overlayButtonBg, in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(shareDestinations.filter(\.isAvailable)) { dest in
                            Button {
                                dest.share(url: profileURL)
                            } label: {
                                VStack(spacing: 6) {
                                    if let assetName = dest.assetIcon {
                                        Image(assetName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 56, height: 56)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: dest.systemIcon)
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundStyle(dest.iconForeground)
                                            .frame(width: 56, height: 56)
                                            .background(dest.brandColor, in: Circle())
                                    }

                                    Text(dest.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(bottomTextColor)
                                }
                            }
                        }

                        ShareLink(
                            item: URL(string: profileURL)!,
                            message: Text("share.connectCallout")
                        ) {
                            VStack(spacing: 6) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(bottomTextColor)
                                    .frame(width: 56, height: 56)
                                    .background(overlayButtonBg, in: Circle())

                                Text("common.other")
                                    .font(.system(size: 11))
                                    .foregroundStyle(bottomTextColor)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .opacity(iconsAppeared ? 1 : 0)
                .offset(y: iconsAppeared ? 0 : 20)
                .padding(.bottom, 44)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.25)) {
                cardAppeared = true
            }
            withAnimation(.spring(duration: 0.4, bounce: 0.15).delay(0.25)) {
                iconsAppeared = true
            }
            withAnimation(.spring(duration: 0.35, bounce: 0.2).delay(0.4)) {
                copied = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(2500))
                withAnimation(.spring(duration: 0.3)) {
                    copied = false
                }
            }
        }
    }

    private var shareDestinations: [ShareDestination] {
        [
            ShareDestination(
                id: "line", label: "LINE",
                assetIcon: "icon-line", systemIcon: "bubble.fill",
                platform: .line,
                urlScheme: "line", shareURL: { "https://line.me/R/share?text=\($0.encodedForURL)" }
            ),
            ShareDestination(
                id: "instagram", label: "Instagram",
                assetIcon: "icon-instagram", systemIcon: "camera.fill",
                platform: .instagram,
                urlScheme: "instagram", shareURL: { _ in "instagram://app" }
            ),
            ShareDestination(
                id: "x", label: "X",
                assetIcon: "icon-x", systemIcon: "xmark",
                platform: .x,
                urlScheme: "twitter", shareURL: { "https://twitter.com/intent/tweet?text=\($0.encodedForURL)" }
            ),
            ShareDestination(
                id: "discord", label: "Discord",
                assetIcon: "icon-discord", systemIcon: "bubble.fill",
                platform: .discord,
                urlScheme: "discord", shareURL: { _ in "discord://app" }
            ),
            ShareDestination(
                id: "github", label: "GitHub",
                assetIcon: "icon-github", systemIcon: "chevron.left.forwardslash.chevron.right",
                platform: .github,
                urlScheme: nil, shareURL: { _ in "" }
            ),
            ShareDestination(
                id: "messages", label: "profile.contact.message",
                assetIcon: nil, systemIcon: "message.fill",
                platform: .messages,
                urlScheme: nil, shareURL: { "sms:&body=\($0.encodedForURL)" }
            ),
            ShareDestination(
                id: "mail", label: "profile.contact.email",
                assetIcon: nil, systemIcon: "envelope.fill",
                platform: .mail,
                urlScheme: nil, shareURL: { "mailto:?subject=CreateLog&body=\($0.encodedForURL)" }
            ),
        ]
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 220.0 / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Action Button Style

private extension Text {
    func profileActionButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.clTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
    }
}
