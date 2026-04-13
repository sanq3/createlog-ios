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
            // Login info
            Section {
                settingsRow(
                    title: "メールアドレス",
                    detail: userInfo?.email ?? "読み込み中..."
                )
                NavigationLink {
                    PasswordResetView()
                } label: {
                    HStack {
                        Text("パスワード")
                            .font(.clBody)
                            .foregroundStyle(Color.clTextPrimary)
                        Spacer()
                        Text("リセットメール送信")
                            .font(.clBody)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            } header: {
                Text("ログイン情報")
            }

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

    private func settingsRow(title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)
            Spacer()
            Text(detail)
                .font(.clBody)
                .foregroundStyle(Color.clTextTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
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

// MARK: - Password reset

/// メール経由のパスワードリセット画面。
/// Supabase Auth の resetPasswordForEmail を呼ぶだけ。ログイン中でも reset-link を送信できる。
private struct PasswordResetView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var sent = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section {
                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            } footer: {
                Text("このメールアドレス宛にパスワードリセット用のリンクを送信します。")
                    .font(.clCaption)
            }

            if sent {
                Section {
                    Text("リセットメールを送信しました。メールの指示に従ってください。")
                        .font(.clCaption)
                        .foregroundStyle(Color.clSuccess)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.clCaption)
                        .foregroundStyle(Color.clError)
                }
            }

            Section {
                Button {
                    Task { await sendResetEmail() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("リセットメールを送信")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(email.isEmpty || isLoading)
            }
        }
        .task {
            // 現在ユーザーの email を初期値として入れる
            if email.isEmpty {
                let info = await dependencies.authService.currentUserInfo
                email = info?.email ?? ""
            }
        }
        .navigationTitle("パスワードをリセット")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendResetEmail() async {
        guard !email.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await dependencies.authService.sendPasswordResetEmail(to: email)
            sent = true
        } catch {
            errorMessage = "送信に失敗しました。しばらくしてから再試行してください。"
        }
    }
}
