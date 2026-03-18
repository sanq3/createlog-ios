import SwiftUI

struct DiscoverView: View {
    @State private var searchText = ""

    private let trendingTags = ["SwiftUI", "個人開発", "React", "Flutter", "AI", "TypeScript"]
    private let suggestedUsers = [
        (name: "山田太郎", desc: "iOS開発 3年 / 連続42日", initials: "山"),
        (name: "Emily Chen", desc: "Full Stack / 1200h total", initials: "E"),
        (name: "鈴木一郎", desc: "AI/ML / 今週28h", initials: "鈴")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trending tags
                VStack(alignment: .leading, spacing: 10) {
                    Text("トレンドタグ")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(trendingTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clSurfaceLow, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.clBorder, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Suggested users
                VStack(alignment: .leading, spacing: 12) {
                    Text("おすすめエンジニア")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    ForEach(suggestedUsers, id: \.name) { user in
                        HStack(spacing: 12) {
                            AvatarView(initials: user.initials, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.clHeadline)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text(user.desc)
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Spacer()

                            Button {
                                HapticManager.light()
                            } label: {
                                Text("フォロー")
                                    .font(.clCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.clTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.clSurfaceLow, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.clBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)

                        Divider().overlay(Color.clBorder).padding(.leading, 68)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("発見")
        .searchable(text: $searchText, prompt: "ユーザー、タグ、アプリを検索")
    }
}
