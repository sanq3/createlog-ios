import SwiftUI

struct NotificationItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let actor: String
    let message: String
    let time: String
}

struct NotificationsView: View {
    @State private var filterIndex = 0

    private let notifications: [NotificationItem] = [
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "田中", message: "があなたの投稿にいいねしました", time: "3分前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "Emily", message: "があなたをフォローしました", time: "1時間前"),
        NotificationItem(icon: "arrow.2.squarepath", iconColor: .clSuccess, actor: "佐藤", message: "があなたの投稿をリポストしました", time: "3時間前"),
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "yuki", message: "が記録に反応しました", time: "5時間前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "鈴木", message: "があなたをフォローしました", time: "昨日"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CLSegmentedControl(
                    items: ["すべて", "いいね", "フォロー", "メンション"],
                    selection: $filterIndex
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                LazyVStack(spacing: 0) {
                    ForEach(notifications) { notif in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(notif.iconColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: notif.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(notif.iconColor)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                (Text(notif.actor).fontWeight(.semibold).foregroundColor(Color.clTextPrimary)
                                 + Text(notif.message).foregroundColor(Color.clTextSecondary))
                                    .font(.clBody)

                                Text(notif.time)
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        Divider().overlay(Color.clBorder).padding(.leading, 68)
                    }
                }
                .padding(.top, 12)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("通知")
    }
}
