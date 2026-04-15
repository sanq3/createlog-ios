import PhotosUI
import SwiftUI

@MainActor @Observable
final class ComposeViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let postRepository: (any PostRepositoryProtocol)?

    // MARK: - State

    var text = ""
    var attachedImages: [AttachedImageData] = []
    var attachedCode: AttachedCode?
    var showCodeEditor = false
    var isPosting = false
    var errorMessage: String?
    var didPost = false

    // MARK: - Constants

    @ObservationIgnored let maxImages = 4
    @ObservationIgnored private let articleThreshold = 300

    // MARK: - Init

    init(postRepository: (any PostRepositoryProtocol)? = nil) {
        self.postRepository = postRepository
    }

    // MARK: - Computed

    var canPost: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !attachedImages.isEmpty || attachedCode != nil
        return hasText || hasMedia
    }

    var canAddImages: Bool { attachedImages.count < maxImages }
    var canAddCode: Bool { attachedCode == nil }
    var remainingImageSlots: Int { maxImages - attachedImages.count }

    // MARK: - Actions

    func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        for item in items {
            guard attachedImages.count < maxImages else { break }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data)
                {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        attachedImages.append(AttachedImageData(image: uiImage))
                    }
                }
            }
        }
    }

    func removeImage(id: UUID) {
        HapticManager.light()
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            attachedImages.removeAll { $0.id == id }
        }
    }

    func removeCode() {
        HapticManager.light()
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            attachedCode = nil
        }
    }

    func post() async {
        guard canPost else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        // Phase 1 (2026-04-16): 画像があれば先に 2 サイズ (thumb 480px / full 1920px) 生成 + upload、
        // 戻ってきた PostMediaItem 配列を DTO に入れる。upload 失敗時は post 自体を中止し、
        // ユーザーにエラーを表示してリトライさせる (中途半端な「画像なし投稿」防止)。
        var uploadedMedia: [PostMediaItem] = []
        for attached in attachedImages {
            let original = attached.image
            let fullImage = original.resized(maxDimension: 1920)
            let thumbImage = original.resized(maxDimension: 480)
            guard let fullData = fullImage.jpegData(compressionQuality: 0.85),
                  let thumbData = thumbImage.jpegData(compressionQuality: 0.85) else {
                errorMessage = "画像の処理に失敗しました"
                HapticManager.error()
                return
            }
            do {
                let item = try await postRepository?.uploadPostMedia(
                    thumbData: thumbData,
                    fullData: fullData,
                    contentType: "image/jpeg",
                    width: Int(fullImage.size.width),
                    height: Int(fullImage.size.height)
                )
                if let item {
                    uploadedMedia.append(item)
                }
            } catch {
                errorMessage = "画像のアップロードに失敗しました"
                HapticManager.error()
                return
            }
        }

        let dto = PostInsertDTO(
            content: text,
            media: uploadedMedia,
            visibility: "public"
        )

        do {
            _ = try await postRepository?.insertPost(dto)
            didPost = true
            HapticManager.success()
        } catch {
            errorMessage = "投稿に失敗しました"
            HapticManager.error()
        }
    }

    func reset() {
        text = ""
        attachedImages = []
        attachedCode = nil
        errorMessage = nil
        didPost = false
    }
}

// MARK: - Supporting Types

struct AttachedImageData: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AttachedCode {
    var code: String
    var language: String
}
