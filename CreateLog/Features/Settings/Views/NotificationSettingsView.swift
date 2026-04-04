import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notification.push") private var pushEnabled = true
    @AppStorage("notification.likes") private var likesEnabled = true
    @AppStorage("notification.comments") private var commentsEnabled = true
    @AppStorage("notification.follows") private var followsEnabled = true
    @AppStorage("notification.mentions") private var mentionsEnabled = true
    @AppStorage("notification.reposts") private var repostsEnabled = true
    @AppStorage("notification.system") private var systemEnabled = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $pushEnabled) {
                    Label {
                        Text("プッシュ通知")
                            .font(.clBody)
                            .foregroundStyle(Color.clTextPrimary)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Color.clAccent)
                    }
                }
                .tint(Color.clAccent)
            } footer: {
                Text("オフにすると全てのプッシュ通知が停止します")
                    .font(.clCaption)
            }

            Section {
                notificationToggle(
                    icon: "heart.fill",
                    color: Color.clError,
                    title: "いいね",
                    subtitle: "投稿へのいいね",
                    isOn: $likesEnabled
                )
                notificationToggle(
                    icon: "bubble.right.fill",
                    color: Color.clAccent,
                    title: "コメント",
                    subtitle: "投稿へのコメント",
                    isOn: $commentsEnabled
                )
                notificationToggle(
                    icon: "person.fill.badge.plus",
                    color: Color.clSuccess,
                    title: "フォロー",
                    subtitle: "新しいフォロワー",
                    isOn: $followsEnabled
                )
                notificationToggle(
                    icon: "at",
                    color: .orange,
                    title: "メンション",
                    subtitle: "投稿でのメンション",
                    isOn: $mentionsEnabled
                )
                notificationToggle(
                    icon: "arrow.2.squarepath",
                    color: .purple,
                    title: "リポスト",
                    subtitle: "投稿のリポスト",
                    isOn: $repostsEnabled
                )
            } header: {
                Text("アクティビティ")
            }

            Section {
                notificationToggle(
                    icon: "gearshape.fill",
                    color: Color.clTextTertiary,
                    title: "システム通知",
                    subtitle: "メンテナンス、アップデート情報",
                    isOn: $systemEnabled
                )
            } header: {
                Text("その他")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func notificationToggle(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.clBody)
                        .foregroundStyle(Color.clTextPrimary)
                    Text(subtitle)
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)
                }
            }
        }
        .tint(Color.clAccent)
        .disabled(!pushEnabled)
        .opacity(pushEnabled ? 1 : 0.4)
    }
}
