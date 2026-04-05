import SwiftUI

struct AccountSettingsView: View {
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteText = ""

    var body: some View {
        List {
            // Login info
            Section {
                settingsRow(
                    title: "メールアドレス",
                    detail: "user@example.com"
                )
                settingsRow(
                    title: "パスワード",
                    detail: "変更"
                )
            } header: {
                Text("ログイン情報")
            }

            // Linked accounts
            Section {
                linkedAccountRow(
                    provider: "Apple",
                    icon: "apple.logo",
                    isLinked: true
                )
                linkedAccountRow(
                    provider: "Google",
                    icon: "g.circle.fill",
                    isLinked: false
                )
                linkedAccountRow(
                    provider: "GitHub",
                    icon: "chevron.left.forwardslash.chevron.right",
                    isLinked: true
                )
            } header: {
                Text("連携アカウント")
            }

            // Logout
            Section {
                Button {
                    HapticManager.medium()
                    showLogoutConfirm = true
                } label: {
                    Text("ログアウト")
                        .font(.clBody)
                        .foregroundStyle(Color.clError)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            // Delete account
            Section {
                Button {
                    HapticManager.medium()
                    showDeleteConfirm = true
                } label: {
                    Text("アカウントを削除")
                        .font(.clBody)
                        .foregroundStyle(Color.clError)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("アカウントを削除すると、全てのデータが完全に削除されます。この操作は取り消せません。")
                    .font(.clCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("ログアウトしますか？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) {
                HapticManager.medium()
            }
        }
        .alert("アカウントの削除", isPresented: $showDeleteConfirm) {
            TextField("「削除」と入力", text: $deleteText)
            Button("削除する", role: .destructive) {
                HapticManager.error()
            }
            .disabled(deleteText != "削除")
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。確認のため「削除」と入力してください。")
        }
    }

    // MARK: - Rows

    private func settingsRow(title: String, detail: String) -> some View {
        NavigationLink {
            // Placeholder for detail editing
            Text(title)
                .navigationTitle(title)
        } label: {
            HStack {
                Text(title)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextPrimary)
                Spacer()
                Text(detail)
                    .font(.clBody)
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
    }

    private func linkedAccountRow(provider: String, icon: String, isLinked: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.clTextPrimary)
                .frame(width: 28)

            Text(provider)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            if isLinked {
                Text("連携済み")
                    .font(.clCaption)
                    .foregroundStyle(Color.clSuccess)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.clSuccess.opacity(0.12), in: .capsule)
            } else {
                Button {
                    HapticManager.light()
                } label: {
                    Text("連携する")
                        .font(.clCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.clAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.clAccent.opacity(0.12), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
