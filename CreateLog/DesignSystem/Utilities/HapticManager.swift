import UIKit

/// `UIFeedbackGenerator` 系は main-actor 隔離のため、`@MainActor` を付けないと
/// Swift 6 strict concurrency で全 call site が警告になる。Haptic は UI 反応の
/// 一部で必ず main 上で発火させる想定なので、namespace 単位で MainActor にする。
@MainActor
enum HapticManager {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
