import SwiftUI

/// 通知設定画面。v2.0.0 では OS の通知許可設定への誘導と、今後の種類別フィルタの予告のみ。
/// 以前の `@AppStorage("notification.*")` 7 個のトグルは、サーバーサイド (APNs 送信側) で
/// 一切参照されておらず「設定しても通知は来る」という嘘の画面になっていたため削除。
/// v2.1 で `user_notification_preferences` テーブル + Edge Function 側のフィルタ実装とセットで再導入する。
struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Button {
                    HapticManager.light()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.clAccent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("notification.permission.title")
                                .font(.clBody)
                                .foregroundStyle(Color.clTextPrimary)
                            Text("notification.permission.hint")
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            } footer: {
                Text("notification.settings.description")
                    .font(.clCaption)
            }

            Section {
                comingSoonRow(
                    icon: "slider.horizontal.3",
                    title: "settings.notification.typeFilter",
                    subtitle: "settings.notification.typeFilter.description"
                )
                comingSoonRow(
                    icon: "moon.fill",
                    title: "settings.notification.dnd.title",
                    subtitle: "settings.notification.dnd.description"
                )
            } header: {
                Text("common.comingSoonLong")
            } footer: {
                Text("common.comingSoon.description")
                    .font(.clCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("notification.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comingSoonRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.clTextTertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextPrimary)
                Text(subtitle)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()

            Text("common.comingSoon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.clTextTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.clTextTertiary.opacity(0.12), in: .capsule)
        }
        .opacity(0.75)
    }
}
