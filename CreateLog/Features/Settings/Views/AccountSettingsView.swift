import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: AuthViewModel?
    @State private var userInfo: CurrentUserInfo?
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteText = ""

    var body: some View {
        List {
            // Linked accounts
            Section {
                linkedAccountRow(provider: "Apple", icon: "apple.logo", isLinked: isLinked("apple"))
                linkedAccountRow(provider: "Google", icon: "g.circle.fill", isLinked: isLinked("google"))
                linkedAccountRow(provider: "GitHub", icon: "chevron.left.forwardslash.chevron.right", isLinked: isLinked("github"))
            } header: {
                Text("連携アカウント")
            } footer: {
                Text("連携アカウントの追加・解除は現在サポートしていません。")
                    .font(.clCaption)
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

            if let errorMessage = viewModel?.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.clCaption)
                        .foregroundStyle(Color.clError)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(authService: dependencies.authService)
            }
            userInfo = await viewModel?.loadCurrentUserInfo()
        }
        .confirmationDialog("ログアウトしますか？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) {
                HapticManager.medium()
                Task { await viewModel?.signOut() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("アカウントの削除", isPresented: $showDeleteConfirm) {
            TextField("「削除」と入力", text: $deleteText)
            Button("削除する", role: .destructive) {
                HapticManager.error()
                Task {
                    await viewModel?.deleteAccount()
                    deleteText = ""
                }
            }
            .disabled(deleteText != "削除")
            Button("キャンセル", role: .cancel) {
                deleteText = ""
            }
        } message: {
            Text("この操作は取り消せません。確認のため「削除」と入力してください。")
        }
    }

    // MARK: - Helpers

    private func isLinked(_ provider: String) -> Bool {
        userInfo?.linkedProviders.contains(provider) ?? false
    }

    // MARK: - Rows

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
                Text("未連携")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.clTextTertiary.opacity(0.1), in: .capsule)
            }
        }
    }
}

