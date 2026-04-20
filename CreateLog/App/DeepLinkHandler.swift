import Foundation

/// ディープリンクのルーティング
enum DeepLink: Equatable {
    case post(id: UUID)
    case profile(handle: String)
    case notifications
    case record

    /// URL からパース。
    ///
    /// 2026-04-20 (security): 任意の URL から呼ばれうるため入力 validation を追加:
    /// - scheme は `createlog` (URL scheme) または `https` で host が `createlog.app` のみ許容 (Universal Links)
    /// - URL 全体長 512 char 上限 (DoS / 巨大 payload 対策)
    /// - handle は `OnboardingViewModel.HandleValidation` と同条件の regex で厳格 match
    ///   (3-15 char、先頭 letter、英数+_)
    /// - Universal Links は handle URL が prefix なし (`/{handle}`) で配布される設計に従い、
    ///   1 segment の path は handle として解釈 (`/post/{uuid}` のみ別扱い)
    static func parse(_ url: URL) -> DeepLink? {
        guard url.absoluteString.count <= 512 else { return nil }

        let isCustomScheme = url.scheme == "createlog"
        let isUniversalLink = url.scheme == "https" &&
            (url.host == "createlog.app" || url.host == "www.createlog.app")
        guard isCustomScheme || isUniversalLink else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }

        // post/{uuid} (UUID 形式のみ、UUID init が format 検証)
        // - createlog://post/{uuid}
        // - https://createlog.app/post/{uuid}
        if components.first == "post",
           let idString = components.dropFirst().first,
           let id = UUID(uuidString: idString) {
            return .post(id: id)
        }

        // notifications
        if components.first == "notifications" {
            return .notifications
        }

        // record
        if components.first == "record" {
            return .record
        }

        // createlog://profile/{handle} (legacy URL scheme path、handle 形式を厳格 validate)
        if isCustomScheme,
           components.first == "profile",
           let rawHandle = components.dropFirst().first,
           isValidHandle(rawHandle) {
            return .profile(handle: rawHandle)
        }

        // https://createlog.app/{handle} (Universal Links: prefix なし handle URL)
        // 1 segment のみ かつ handle regex match の場合に handle 扱い。
        // post/notifications/record 等の予約語は上の分岐で handled、
        // 静的 Web ページ (privacy/terms/support/en 等) は handle regex (3-15 char、先頭 letter) で弾かれる。
        if isUniversalLink,
           components.count == 1,
           let rawHandle = components.first,
           isValidHandle(rawHandle) {
            return .profile(handle: rawHandle)
        }

        return nil
    }

    /// handle が `^[a-zA-Z][a-zA-Z0-9_]{2,14}$` を満たすか。
    /// OnboardingViewModel.HandleValidation / profiles.handle CHECK 制約と一致。
    private static func isValidHandle(_ handle: String) -> Bool {
        guard (3...15).contains(handle.count) else { return false }
        let regex = try? NSRegularExpression(pattern: "^[a-zA-Z][a-zA-Z0-9_]{2,14}$")
        let range = NSRange(location: 0, length: handle.utf16.count)
        return regex?.firstMatch(in: handle, range: range) != nil
    }
}

/// ディープリンクの状態管理
@MainActor @Observable
final class DeepLinkHandler {
    var pendingLink: DeepLink?

    func handle(_ url: URL) {
        pendingLink = DeepLink.parse(url)
    }

    func consume() -> DeepLink? {
        let link = pendingLink
        pendingLink = nil
        return link
    }
}
