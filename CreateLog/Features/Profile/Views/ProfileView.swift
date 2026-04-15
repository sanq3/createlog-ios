import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @Environment(\.dependencies) private var deps
    /// オンボーディングで作成したローカル SDProject。remote (apps) に同期済 (remoteAppId != nil)
    /// は ProfileViewModel.apps 経由で出るので除外し、二重表示を防ぐ。
    @Query(
        filter: #Predicate<SDProject> { $0.remoteAppId == nil },
        sort: \SDProject.createdAt,
        order: .reverse
    )
    private var localProjects: [SDProject]
    /// 2026-04-16: 非 optional 化 (SWR + cache-first rendering)。init で dependencies を受け取り、
    /// `ProfileViewModel.init` 内で `SDProfileCache` から同期的に profile を fetch する。
    /// これで View 初回描画時に `User(name:"", handle:"")` の空 User が見える flicker を根絶。
    @State private var viewModel: ProfileViewModel
    @State private var showShareSheet = false
    @State private var showEditProfile = false

    init(dependencies: DependencyContainer) {
        _viewModel = State(initialValue: ProfileViewModel(
            profileRepository: dependencies.profileRepository,
            postRepository: dependencies.postRepository,
            appRepository: dependencies.appRepository,
            followRepository: dependencies.followRepository,
            statsRepository: dependencies.statsRepository
        ))
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
                        profileStat(value: "\(userPosts.count)", label: "投稿")
                        Spacer()
                        NavigationLink {
                            FollowListView(initialTab: .followers)
                        } label: {
                            profileStat(value: "\(user.followerCount)", label: "フォロワー")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        NavigationLink {
                            FollowListView(initialTab: .following)
                        } label: {
                            profileStat(value: "\(user.followingCount)", label: "フォロー中")
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

                    Text("累計 \(Int(user.totalHours))h")
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
                        Text("プロフィールを編集")
                            .profileActionButton()
                    }

                    Button {
                        UIPasteboard.general.string = handle
                        HapticManager.light()
                        showShareSheet = true
                    } label: {
                        Text("プロフィールをシェア")
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
                    Text("マイプロダクト")
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

                // 投稿セクション
                // v2.0.0: タブ (投稿 / いいね / ブックマーク) は投稿のみに。
                // いいね・ブックマークの一覧は対応 Repository 未実装 (LikeRepository.fetchLiked なし、
                // BookmarkRepository なし) のため v2.1 で再導入する。
                VStack(spacing: 0) {
                    HStack {
                        Text("投稿")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    Divider()
                        .foregroundStyle(Color.clBorder)

                    postsListSection
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
            ProfileEditView(user: user, profileRepository: deps.profileRepository)
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
        }
    }

    @ViewBuilder
    private var postsListSection: some View {
        if userPosts.isEmpty {
            Text("まだ投稿がありません")
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(userPosts) { post in
                    PostCardView(post: post)
                }
            }
            .padding(.top, 12)
        }
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

    private func localProjectCard(project: SDProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                projectIcon(project: project)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextPrimary)
                            .lineLimit(1)

                        statusBadge(for: project.status)
                    }

                    if !project.platforms.isEmpty {
                        Text(project.platforms.joined(separator: " / "))
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    if !project.techStack.isEmpty {
                        Text(project.techStack.prefix(4).joined(separator: ", "))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.clTextTertiary.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            if !project.appDescription.isEmpty {
                Text(project.appDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextSecondary)
                    .lineLimit(3)
            }

            if project.storeURL?.isEmpty == false || project.githubURL?.isEmpty == false {
                HStack(spacing: 12) {
                    if let store = project.storeURL, !store.isEmpty {
                        projectLinkChip(icon: "arrow.up.forward.app", label: storeChipLabel(for: project))
                    }
                    if let github = project.githubURL, !github.isEmpty {
                        projectLinkChip(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub")
                    }
                }
            }
        }
        .padding(14)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
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

    private func projectLinkChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.clAccent)
    }

    /// store URL の host から App Store / Play Store / Web を判別してラベル化。
    /// 詳細解析が要らない最小ヒューリスティック。
    private func storeChipLabel(for project: SDProject) -> String {
        guard let url = project.storeURL?.lowercased() else { return "Web" }
        if url.contains("apps.apple.com") { return "App Store" }
        if url.contains("play.google.com") { return "Google Play" }
        return "Web"
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
                        Text("コピーしました!")
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
                            message: Text("CreateLogで繋がろう!")
                        ) {
                            VStack(spacing: 6) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(bottomTextColor)
                                    .frame(width: 56, height: 56)
                                    .background(overlayButtonBg, in: Circle())

                                Text("その他")
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
                id: "messages", label: "メッセージ",
                assetIcon: nil, systemIcon: "message.fill",
                platform: .messages,
                urlScheme: nil, shareURL: { "sms:&body=\($0.encodedForURL)" }
            ),
            ShareDestination(
                id: "mail", label: "メール",
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
