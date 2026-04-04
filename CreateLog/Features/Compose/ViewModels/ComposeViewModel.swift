import PhotosUI
import SwiftUI

@MainActor @Observable
final class ComposeViewModel {

    // MARK: - State

    var text = ""
    var attachedImages: [AttachedImageData] = []
    var attachedCode: AttachedCode?
    var showCodeEditor = false

    // MARK: - Constants

    @ObservationIgnored let maxImages = 4
    @ObservationIgnored private let articleThreshold = 300

    // MARK: - Computed

    var detectedType: ComposeContentType {
        if attachedCode != nil {
            return .codeSnippet
        } else if text.count > articleThreshold {
            return .article
        }
        return .post
    }

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
