import Foundation

/// 投稿の画像 1 枚分のメタデータ。`posts.media_urls` (jsonb) の要素として保存される。
///
/// ## 3 phase 対応 (schema は全 phase 共通)
/// - Phase 1 (Supabase Free + client 2 サイズ生成): `url` = full 1920px, `thumbUrl` = thumb 480px (両方 upload 済)
/// - Phase 2 (Cloudflare R2 移行): 同上、URL host だけ変わる
/// - Phase 3 (Smart CDN dynamic resize): `url` = original 1 枚のみ、`thumbUrl` = null。
///   client 側で `thumbUrl ?? transformURL(url, width: 480)` として fallback し、CDN の
///   `?width=480` parameter で動的 resize を要求する (Instagram/Twitter/Bluesky 業界標準)。
///
/// ## UI 用途
/// - `width` / `height`: レイアウト前計算に使い、画像ロード前でも正しい aspect ratio の place を確保する
///   (Instagram Stories pattern、Cumulative Layout Shift = 0 を実現)。
struct PostMediaItem: Codable, Sendable, Equatable, Hashable {
    /// Full-size 画像 URL (Phase 1/2 は client 生成 1920px, Phase 3 は CDN original)。
    var url: String
    /// Thumbnail URL (Phase 1/2 は client 生成 480px、Phase 3 は null → client 動的生成)。
    var thumbUrl: String?
    /// original (full) の画像幅 (pixel)。
    var width: Int
    /// original (full) の画像高さ (pixel)。
    var height: Int

    enum CodingKeys: String, CodingKey {
        case url, width, height
        case thumbUrl = "thumb_url"
    }

    init(url: String, thumbUrl: String? = nil, width: Int, height: Int) {
        self.url = url
        self.thumbUrl = thumbUrl
        self.width = width
        self.height = height
    }

    /// aspect ratio (width / height)。0 除算回避で height=0 時は 1.0 を返す。
    var aspectRatio: Double {
        guard height > 0 else { return 1.0 }
        return Double(width) / Double(height)
    }

    /// UI で実際に表示する URL を決定する。
    /// Phase 1/2: `thumbUrl` が埋まっていればそれを使う (480px)。
    /// Phase 3: `thumbUrl` が nil なので `url` を Supabase Smart CDN / Cloudflare の transformation endpoint に通す。
    ///
    /// ## Phase 3 実装 (後で有効化)
    /// ```swift
    /// return "\(url)?width=\(targetWidth)&quality=80"
    /// ```
    func displayURL(preferredWidth: Int) -> String {
        if let thumbUrl, preferredWidth <= 480 {
            return thumbUrl
        }
        return url
    }
}
