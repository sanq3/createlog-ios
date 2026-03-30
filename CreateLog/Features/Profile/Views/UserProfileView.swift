import SwiftUI

struct UserProfileView: View {
    @State private var user: User
    @State private var showUnfollowConfirmation = false
    @State private var showReportMenu = false

    init(user: User) {
        _user = State(initialValue: user)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                actionButtons
                statsSection
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
                        print("[UserProfile] Report user: \(user.handle)")
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.triangle")
                    }
                    Button(role: .destructive) {
                        print("[UserProfile] Block user: \(user.handle)")
                    } label: {
                        Label("ブロックする", systemImage: "slash.circle")
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
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    user.isFollowing = false
                }
                HapticManager.light()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                AvatarView(initials: user.initials, size: 80, status: user.status)

                Spacer()

                HStack(spacing: 0) {
                    profileStat(value: "\(user.followerCount)", label: "フォロワー")
                    Spacer()
                    profileStat(value: "\(user.followingCount)", label: "フォロー中")
                    Spacer()
                    profileStat(value: "\(user.projectCount)", label: "プロジェクト")
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextPrimary)

                Text("@\(user.handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.top, 4)
                }
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
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        user.isFollowing = true
                    }
                    HapticManager.light()
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

            Button {
                HapticManager.light()
                print("[UserProfile] Message user: \(user.handle)")
            } label: {
                Text("メッセージ")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 10) {
            statBadge(
                icon: "clock.fill",
                value: formatHours(user.totalHours),
                label: "累計"
            )
            statBadge(
                icon: "flame.fill",
                value: "\(user.streak)日",
                label: "連続"
            )
            statBadge(
                icon: "hammer.fill",
                value: "\(user.projectCount)",
                label: "プロジェクト"
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プロジェクト")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(MockData.projects.prefix(2))) { project in
                        projectCard(project)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Posts

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投稿")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                ForEach(Array(MockData.posts.prefix(3))) { post in
                    PostCardView(post: post)
                }
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Components

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

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.clAccent)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.clTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
    }

    private func projectCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: project.iconColor.red,
                                    green: project.iconColor.green,
                                    blue: project.iconColor.blue
                                ),
                                Color(
                                    red: project.iconColor.red * 0.7,
                                    green: project.iconColor.green * 0.7,
                                    blue: project.iconColor.blue * 0.7
                                ),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(project.iconInitials)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                    Text(project.platform.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.clTextTertiary)
                }
            }

            Text(project.description)
                .font(.system(size: 13))
                .foregroundStyle(Color.clTextSecondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(width: 220, alignment: .leading)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
    }

    private func formatHours(_ hours: Double) -> String {
        if hours >= 1000 {
            return String(format: "%.1fK h", hours / 1000)
        }
        return "\(Int(hours))h"
    }
}
