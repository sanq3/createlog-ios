import SwiftUI

struct UserProfileView: View {
    @State private var user: User
    @State private var showUnfollowConfirmation = false
    init(user: User) {
        _user = State(initialValue: user)
    }

    /// 空状態フォールバック (実データ取得前)
    static let demoWeeklyHours: [(day: String, hours: Double)] = [
        ("月", 0), ("火", 0), ("水", 0), ("木", 0), ("金", 0), ("土", 0), ("日", 0)
    ]
    #if DEBUG
    static let demoProjects: [Project] = Array(MockData.projects.prefix(2))
    static let demoPosts: [Post] = Array(MockData.posts.prefix(3))
    #else
    static let demoProjects: [Project] = []
    static let demoPosts: [Post] = []
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                actionButtons

                // 週間チャート
                WeeklyChart(data: Self.demoWeeklyHours)
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
                        // TODO: 通報機能
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.triangle")
                    }
                    Button(role: .destructive) {
                        // TODO: ブロック機能
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
                AvatarView(initials: user.initials, size: 86, status: user.status)

                Spacer()

                HStack(spacing: 0) {
                    profileStat(value: "\(user.projectCount)", label: "投稿")
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

        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Services (vertical list with reviews)

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("マイサービス")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .padding(.horizontal, 16)

            ForEach(Self.demoProjects) { project in
                serviceCard(project: project)
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
                ForEach(Self.demoPosts) { post in
                    PostCardView(post: post)
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
