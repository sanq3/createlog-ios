import UIKit

extension UIImage {
    /// 長辺を `maxDimension` に縮小する。元画像の方が小さければ自分を返す。
    ///
    /// ## EXIF / metadata 削除
    /// `UIGraphicsImageRenderer` で draw した時点で EXIF / GPS / Maker Note 等の metadata は
    /// preserved されない (純粋な pixel data のみの新 UIImage になる) ため、プライバシー
    /// 観点の EXIF 削除と同時に行える。**Supabase Storage に upload する前に必ず通す**。
    ///
    /// ## HEIC → JPEG の暗黙変換
    /// 本メソッドの戻り値に `jpegData(compressionQuality:)` を呼べば、内部の CGImage が
    /// HEIC でも JPEG 形式でエンコードされる。iOS カメラ default は HEIC だが本アプリでは
    /// 互換性優先で JPEG で配信するため、HEIC の場合もこのフローで透過対応可能。
    ///
    /// ## Phase 1 ユースケース
    /// - thumb: `resized(maxDimension: 480)` → 約 50KB
    /// - full: `resized(maxDimension: 1920)` → 約 500KB
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        let scale = maxDimension / maxSide
        let newSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        // 1x で純粋 pixel 数で描画 (Retina scale 適用しない、意図したサイズになる)
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
