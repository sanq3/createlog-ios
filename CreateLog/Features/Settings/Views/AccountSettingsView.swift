import SwiftUI

/// アカウント画面。v2.0.0 では「ログアウト」と「アカウント削除」の 2 アクションのみ提供する。
/// 以前存在した「ログイン情報」「連携アカウント」sections は削除済み:
/// - ログイン情報 (メアド + パスワードリセット): Email/Password 認証廃止 (2026-04-16) に伴い削除。
/// - 連携アカウント (Apple/Google/GitHub の 連携済み/未連携 表示): 追加・解除操作が未実装で
///   footer で「現在サポートしていません」と自認していた冗長表示のため削除。provider 情報が
///   必要になるのはアカウント削除や問い合わせ時で、別経路で提供する。
struct AccountSettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: AuthViewModel?
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
}
