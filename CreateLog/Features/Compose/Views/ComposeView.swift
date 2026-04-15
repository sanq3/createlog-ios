import SwiftUI

// MARK: - ComposeView
//
// v2.0.0: テキスト投稿のみをサポート。
// 画像添付 (PhotosPicker) / コード添付 / 長文→記事への自動切替判定は v2.1 で再実装する。
// ComposeViewModel 側には関連ロジック (handlePhotoSelection, attachedCode 等) が残っているが
// View からは配線しない。v2.1 で Supabase Storage の post-media bucket + RLS 整備と合わせて有効化予定。

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ComposeViewModel?
    /// ログイン中ユーザーのプロフィール (アバター表示用)。.task で取得。
    @State private var user: User = User(name: "", handle: "")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        AvatarView(
                            initials: user.initials,
                            size: 40,
                            status: .offline,
                            imageURL: user.avatarUrl.flatMap(URL.init(string:))
                        )

                        AutoFocusTextView(text: Binding(
                            get: { viewModel?.text ?? "" },
                            set: { viewModel?.text = $0 }
                        ))
                            .frame(minHeight: 220)
                            .overlay(alignment: .topLeading) {
                                if (viewModel?.text ?? "").isEmpty {
                                    Text("いまなにしてる?")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.clTextTertiary)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if viewModel == nil {
                    viewModel = ComposeViewModel(postRepository: dependencies.postRepository)
                }
                // 現在ユーザーのプロフィール取得 (アバター表示用)
                if let dto = try? await dependencies.profileRepository.fetchMyProfile() {
                    user = User(from: dto)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.clTextPrimary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.medium()
                        Task {
                            await viewModel?.post()
                            if viewModel?.didPost == true {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel?.isPosting == true {
                                ProgressView()
                                    .tint(Color.clAccent)
                            }
                            Text("投稿")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(
                                    (viewModel?.canPost ?? false) && viewModel?.isPosting != true
                                        ? Color.clAccent
                                        : Color.clAccent.opacity(0.4)
                                )
                        }
                    }
                    .disabled(!(viewModel?.canPost ?? false) || viewModel?.isPosting == true)
                }
            }
            .errorBanner(Binding(
                get: { viewModel?.errorMessage },
                set: { viewModel?.errorMessage = $0 }
            ))
        }
    }
}
