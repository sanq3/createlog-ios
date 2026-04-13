import UIKit
import Foundation

/// SwiftUI アプリに AppDelegate フックを挿す薄いアダプタ。
///
/// ## 責務
/// APNs device token 受信 → `NotificationCenter` にポストするだけ。
/// それ以外の lifecycle は SwiftUI の scenePhase で扱う。
///
/// ## Swift 6 safe 設計
/// 旧実装は `nonisolated(unsafe) static var` で PushNotificationService への callback を保持していたが、
/// これは shared mutable state の data race risk。`NotificationCenter.post` 経由で疎結合にした。
/// - `AppDelegate` 側: nonisolated な delegate callback から `NotificationCenter.default.post` するだけ
/// - `PushNotificationService` 側: init 時に `NotificationCenter.default.addObserver` で購読
/// - Data / NSError は Sendable なので post object に渡して問題なし
final class AppDelegateAdapter: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationCenter.default.post(
            name: .apnsDeviceTokenReceived,
            object: deviceToken
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(
            name: .apnsRegistrationFailed,
            object: error as NSError
        )
    }
}

extension Notification.Name {
    static let apnsDeviceTokenReceived = Notification.Name("com.sanq3.createlog.apns.deviceTokenReceived")
    static let apnsRegistrationFailed = Notification.Name("com.sanq3.createlog.apns.registrationFailed")
}
