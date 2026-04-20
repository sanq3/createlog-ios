import SwiftUI

/// アカウント画面。v2.0.0 では「ログアウト」と「アカウント削除」の 2 アクションのみ提供する。
/// 以前存在した「ログイン情報」「連携アカウント」sections は削除済み:
/// - ログイン情報 (メアド + パスワードリセット): Email/Password 認証廃止 (2026-04-16) に伴い削除。
/// - 連携アカウント (Apple/Google/GitHub の 連携済み/未連携 表示): 追加・解除操作が未実装で
///   footer で「現在サポートしていません」と自認していた冗長表示のため削除。provider 情報が
///   必要になるのはアカウント削除や問い合わせ時で、別経路で提供する。
struct AccountSettingsView: View {
    /// 2026-04-20: 局所 AuthVM 生成を破棄し、App scope の同一 instance を Environment 経由で受ける。
    /// これにより signOut 成功時に rootView の authState が即 .unauthenticated に切り替わり、
    /// このシート自体が OnboardingView へ dismiss される (大手 SNS の業界標準挙動)。
    @Environment(AuthViewModel.self) private var viewModel
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteText = ""

    var body: some View {
        List {
            // Logout
            Section {
                Button {
                    HapticManager.medium()
                    showLogoutConfirm = true
                } label: {
                    Text("settings.logout")
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
                    Text("settings.account.delete.action")
                        .font(.clBody)
                        .foregroundStyle(Color.clError)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("settings.account.delete.description")
                    .font(.clCaption)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.clCaption)
                        .foregroundStyle(Color.clError)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clBackground)
        .navigationTitle("settings.account.title")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("settings.logout.confirm", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("settings.logout", role: .destructive) {
                HapticManager.medium()
                Task { await viewModel.signOut() }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .alert("settings.account.delete", isPresented: $showDeleteConfirm) {
            TextField("settings.account.delete.confirmPrompt", text: $deleteText)
            Button("common.delete", role: .destructive) {
                HapticManager.error()
                Task {
                    await viewModel.deleteAccount()
                    deleteText = ""
                }
            }
            .disabled(deleteText != "削除")
            Button("common.cancel", role: .cancel) {
                deleteText = ""
            }
        } message: {
            Text("settings.account.delete.confirmDescription")
        }
    }
}
