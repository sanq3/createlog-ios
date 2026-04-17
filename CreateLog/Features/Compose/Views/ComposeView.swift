import PhotosUI
import SwiftUI

// MARK: - ComposeView
//
// v2.0.0 (2026-04-16): テキスト + 画像投稿 (最大 4 枚) をサポート。
// Phase 1: client 側で 2 サイズ生成 (thumb 480px + full 1920px、JPEG 0.85、EXIF 削除)。
//          Supabase Storage `post-media` bucket にアップロード。
// コード添付 / 長文→記事への自動切替判定は v2.1 で再実装する。

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ComposeViewModel?
    @State private var selectedPhotos: [PhotosPickerItem] = []
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
                            .frame(minHeight: 160)
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

                    // 添付画像プレビュー (最大 4 枚)
                    if let vm = viewModel, !vm.attachedImages.isEmpty {
                        attachedImagesSection(vm: vm)
                    }
                }
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .bottomBar)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: viewModel?.remainingImageSlots ?? 4,
                        matching: .images
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                (viewModel?.canAddImages ?? true)
                                    ? Color.clAccent
                                    : Color.clTextTertiary
                            )
                    }
                    .disabled(!(viewModel?.canAddImages ?? true))

                    Spacer()

                    if let count = viewModel?.attachedImages.count, count > 0 {
                        Text("\(count)/\(viewModel?.maxImages ?? 4)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                viewModel?.handlePhotoSelection(newItems)
                selectedPhotos = []
            }
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

    // MARK: - Attached Images Preview

    private func attachedImagesSection(vm: ComposeViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.attachedImages) { imageData in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: imageData.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.clBorder, lineWidth: 1)
                            )

                        Button {
                            vm.removeImage(id: imageData.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(.black.opacity(0.6)))
                                .overlay(
                                    Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: -6, y: 6)
                    }
                }
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 12)
        }
    }
}
