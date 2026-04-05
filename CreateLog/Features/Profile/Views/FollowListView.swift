import SwiftUI

struct FollowListView: View {
    enum Tab: Int, CaseIterable {
        case followers
        case following
    }

    @State private var selectedTab: Tab
    @State private var searchText = ""
    #if DEBUG
    @State private var users: [User] = MockData.users
    #else
    @State private var users: [User] = []
    #endif
    @Namespace private var tabNamespace

    private let followerCount: Int
    private let followingCount: Int

    init(initialTab: Tab = .followers, followerCount: Int = 0, followingCount: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
        self.followerCount = followerCount
        self.followingCount = followingCount
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
            AvatarView(initials: user.initials, size: 44, status: user.status)

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
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            if let index = users.firstIndex(where: { $0.id == user.id }) {
                users[index].isFollowing.toggle()
            }
        }
        HapticManager.light()
    }
}
