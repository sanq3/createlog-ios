import SwiftUI

struct FollowListView: View {
    enum Tab: Int, CaseIterable {
        case followers
        case following
    }

    @Environment(\.dependencies) private var dependencies
    @State private var selectedTab: Tab
    @State private var searchText = ""
    @State private var followerUsers: [User] = []
    @State private var followingUsers: [User] = []
    @State private var isLoading = false
    @Namespace private var tabNamespace

    /// 表示対象ユーザー id (nil なら current user)
    private let targetUserId: UUID?
    private let followerCount: Int
    private let followingCount: Int

    init(initialTab: Tab = .followers, targetUserId: UUID? = nil, followerCount: Int = 0, followingCount: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
        self.targetUserId = targetUserId
        self.followerCount = followerCount
        self.followingCount = followingCount
    }

    private var users: [User] {
        selectedTab == .followers ? followerUsers : followingUsers
    }

    private var filteredUsers: [User] {
        if searchText.isEmpty { return users }
        let query = searchText.lowercased()
        return users.filter {
            $0.name.lowercased().contains(query)
                || $0.handle.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            searchBar
            userList
        }
        .background(Color.clBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadUsers()
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await loadUsers() }
        }
    }

    /// 現在の selectedTab に応じて followers/following を取得する。
    private func loadUsers() async {
        let userId: UUID
        if let target = targetUserId {
            userId = target
        } else if let info = await dependencies.authService.currentUserInfo,
                  let uid = UUID(uuidString: info.userId) {
            userId = uid
        } else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profiles: [ProfileDTO]
            switch selectedTab {
            case .followers:
                profiles = try await dependencies.followRepository.fetchFollowers(userId: userId, limit: 100)
                followerUsers = profiles.map { User(from: $0) }
            case .following:
                profiles = try await dependencies.followRepository.fetchFollowing(userId: userId, limit: 100)
                followingUsers = profiles.map { User(from: $0) }
            }
        } catch {
            // サイレント: 空 state が表示される
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        selectedTab = tab
                    }
                    HapticManager.light()
                } label: {
                    VStack(spacing: 8) {
                        Text(tabLabel(tab))
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(
                                selectedTab == tab ? Color.clTextPrimary : Color.clTextTertiary
                            )

                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)

                            if selectedTab == tab {
                                Rectangle()
                                    .fill(Color.clTextPrimary)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tab_indicator", in: tabNamespace)
                            }
                        }
                        .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextTertiary)

            TextField("検索", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.clSurfaceHigh, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - List

    // MARK: DO NOT REMOVE `.tabViewStyle(.page)` — UIUX regression
    //
    // `.page` は Apple 純正 UIPageViewController wrapper。X / Instagram のプロフィール
    // タブ切替と同じ業界標準実装。architecture.md の「DragGesture 禁止」ルールは自作
    // DragGesture を対象にしており、Apple 純正 wrapper は対象外 (同ルール末尾の
    // 「Apple 純正 swipe API はこのルールの対象外」節を参照)。
    //
    // 縦 List + 横 `.page` は直交しており ScrollView 干渉は発生しない。削除すると X /
    // Instagram に慣れたユーザーが swipe 切替を失い UIUX 後退する。
    //
    // レビュワーへ: 削除提案する前に architecture.md と code-review.md の該当節を
    // 原文で読め。2026-04-13 に swift-reviewer が誤検知した実例あり。
    private var userList: some View {
        TabView(selection: $selectedTab) {
            userListContent
                .tag(Tab.followers)
            userListContent
                .tag(Tab.following)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedTab) { _, _ in
            HapticManager.light()
        }
    }

    private var userListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    NavigationLink {
                        UserProfileView(user: user)
                    } label: {
                        userRow(user)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    private func userRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: user.initials,
                size: 44,
                status: user.status,
                imageURL: user.avatarUrl.flatMap(URL.init(string:))
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                Text("@\(user.handle)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()

            followButton(for: user)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func followButton(for user: User) -> some View {
        Button {
            toggleFollow(user)
        } label: {
            Text(user.isFollowing ? "フォロー中" : "フォロー")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(user.isFollowing ? Color.clTextPrimary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    user.isFollowing ? Color.clSurfaceHigh : Color.clAccent,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            user.isFollowing ? Color.clBorder : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func tabLabel(_ tab: Tab) -> String {
        switch tab {
        case .followers: return "フォロワー \(followerCount)"
        case .following: return "フォロー中 \(followingCount)"
        }
    }

    private func toggleFollow(_ user: User) {
        // オプティミスティック UI: 先にローカル状態を反転して即座に反映
        let wasFollowing = user.isFollowing
        if selectedTab == .followers,
           let idx = followerUsers.firstIndex(where: { $0.id == user.id }) {
            followerUsers[idx].isFollowing.toggle()
        } else if selectedTab == .following,
                  let idx = followingUsers.firstIndex(where: { $0.id == user.id }) {
            followingUsers[idx].isFollowing.toggle()
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
                // rollback
                if selectedTab == .followers,
                   let idx = followerUsers.firstIndex(where: { $0.id == user.id }) {
                    followerUsers[idx].isFollowing = wasFollowing
                } else if selectedTab == .following,
                          let idx = followingUsers.firstIndex(where: { $0.id == user.id }) {
                    followingUsers[idx].isFollowing = wasFollowing
                }
            }
        }
    }
}
