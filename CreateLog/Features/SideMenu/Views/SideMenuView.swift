import SwiftUI

enum SideMenuDestination {
    case profile
    case premium
    case bookmarks
    case followRequests
    case settings
}

struct SideMenuView: View {
    @Binding var isShowing: Bool
    var onNavigate: (SideMenuDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile header
            Button {
                onNavigate(.profile)
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    AvatarView(initials: MockData.currentUser.initials, size: 44, status: MockData.currentUser.status)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(MockData.currentUser.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(MockData.currentUser.handle)")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    HStack(spacing: 20) {
                        followStat(count: "\(MockData.currentUser.followingCount)", label: "フォロー中")
                        followStat(count: "\(MockData.currentUser.followerCount)", label: "フォロワー")
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Menu items
            VStack(spacing: 4) {
                menuItem(icon: "person", title: "プロフィール", destination: .profile)
                menuItem(icon: "star", title: "プレミアム", destination: .premium)
                menuItem(icon: "bookmark", title: "ブックマーク", destination: .bookmarks)
                menuItem(icon: "person.badge.plus", title: "フォローリクエスト", destination: .followRequests)
            }

            Spacer()

            Rectangle()
                .fill(Color.clBorder)
                .frame(height: 0.5)
                .padding(.horizontal, 24)

            menuItem(icon: "gearshape", title: "設定とプライバシー", destination: .settings)
                .padding(.top, 4)
                .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.clBackground)
    }

    private func followStat(count: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(count)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextSecondary)
        }
    }

    private func menuItem(icon: String, title: String, destination: SideMenuDestination) -> some View {
        Button {
            HapticManager.light()
            onNavigate(destination)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}
