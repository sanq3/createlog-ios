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
    /// - scheme は `createlog` のみ許容 (他 scheme は無視)
    /// - URL 全体長 512 char 上限 (DoS / 巨大 payload 対策)
    /// - handle は `OnboardingViewModel.HandleValidation` と同条件の regex で厳格 match
    ///   (3-15 char、先頭 letter、英数+_)
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "createlog" else { return nil }
        guard url.absoluteString.count <= 512 else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }

        // createlog://post/{id} (UUID 形式のみ、UUID init が format 検証)
        if components.first == "post",
           let idString = components.dropFirst().first,
           let id = UUID(uuidString: idString) {
            return .post(id: id)
        }

        // createlog://profile/{handle} (handle 形式を厳格 validate)
        if components.first == "profile",
           let rawHandle = components.dropFirst().first,
           isValidHandle(rawHandle) {
            return .profile(handle: rawHandle)
        }

        // createlog://notifications
        if components.first == "notifications" {
            return .notifications
        }

        // createlog://record
        if components.first == "record" {
            return .record
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
