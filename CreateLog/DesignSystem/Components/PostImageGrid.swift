import SwiftUI

struct PostImageGrid: View {
    let images: [PostImage]

    var body: some View {
        Group {
            switch images.count {
            case 1:
                PostImagePlaceholder(image: images[0], aspectRatio: images[0].aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            case 2:
                HStack(spacing: 3) {
                    PostImagePlaceholder(image: images[0], aspectRatio: 4 / 5)
                    PostImagePlaceholder(image: images[1], aspectRatio: 4 / 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            case 3:
                HStack(spacing: 3) {
                    PostImagePlaceholder(image: images[0], aspectRatio: 3 / 4)
                    VStack(spacing: 3) {
                        PostImagePlaceholder(image: images[1], aspectRatio: nil)
                        PostImagePlaceholder(image: images[2], aspectRatio: nil)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            default:
                let clamped = Array(images.prefix(4))
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        PostImagePlaceholder(image: clamped[0], aspectRatio: nil)
                        PostImagePlaceholder(image: clamped[1], aspectRatio: nil)
                    }
                    HStack(spacing: 3) {
                        PostImagePlaceholder(image: clamped[2], aspectRatio: nil)
                        if clamped.count > 3 {
                            PostImagePlaceholder(image: clamped[3], aspectRatio: nil)
                        }
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct PostImagePlaceholder: View {
    let image: PostImage
    let aspectRatio: CGFloat?

    var body: some View {
        Group {
            // 実際の画像 URL があれば AsyncImage で表示、なければ placeholder 色
            if let urlString = image.thumbUrl ?? image.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderFill
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        placeholderFill
                    @unknown default:
                        placeholderFill
                    }
                }
                .aspectRatio(aspectRatio, contentMode: .fill)
                .clipped()
            } else {
                placeholderFill
                    .aspectRatio(aspectRatio, contentMode: .fill)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }
        }
    }

    private var placeholderFill: some View {
        let c = image.placeholderColor
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: c.red, green: c.green, blue: c.blue),
                        Color(red: c.red * 0.7, green: c.green * 0.7, blue: c.blue * 0.7),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
