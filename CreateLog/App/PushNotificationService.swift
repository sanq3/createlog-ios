import Foundation
import UIKit
import UserNotifications
import OSLog
@preconcurrency import Supabase

private let pushLogger = Logger(subsystem: "com.sanq3.createlog", category: "Push")

/// APNs プッシュ通知の登録 + device token 管理。
///
/// ## 責務
/// - ユーザーに通知権限を要求する (`requestAuthorization`)
/// - APNs device token を取得する (`registerForRemoteNotifications`)
/// - token を Supabase `user_device_tokens` テーブルに upsert する
/// - save 失敗時は `pendingDeviceToken` を UserDefaults に保存 → 次回 launch / auth change で retry
///
/// ## 注意
/// Notification Service Extension / push content decoding は v2.1 (T7d) で対応。
/// v2.0 では「登録 + token 保存 + retry」のみ実装。
///
/// ## Retry 戦略 (業界標準: Apple + PubNub + Customer.io)
/// Apple の推奨は「`didFailToRegisterForRemoteNotificationsWithError` が来たら later retry」。
/// backend 保存失敗は APNs 登録失敗とは独立で、永続キューが必要。
/// - 本実装は UserDefaults に pending token を 1 件保持する軽量 persistence
/// - 次回 `init` 時に retryPendingTokenSaveIfAny() を呼び出し
/// - auth state change (サインイン後など) でも同じ関数を呼び出せば再試行できる
/// - Supabase upsert (ON CONFLICT (user_id, token)) なので idempotent で重複登録 safe
@MainActor @Observable
final class PushNotificationService {

    // MARK: - State

    enum AuthorizationStatus: Sendable {
        case notDetermined
        case denied
        case authorized
        case provisional
    }

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var deviceToken: String?
    var registrationError: String?

    // MARK: - Dependencies

    private let client: SupabaseClient
    private let pendingTokenKey = "push.pendingDeviceToken"

    init(client: SupabaseClient) {
        self.client = client
        observeAPNsNotifications()
        // 前回起動で save 失敗した pending token があれば retry
        Task { await retryPendingTokenSaveIfAny() }
    }

    // MARK: - AppDelegate bridge (NotificationCenter)

    private func observeAPNsNotifications() {
        NotificationCenter.default.addObserver(
            forName: .apnsDeviceTokenReceived,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let data = note.object as? Data else { return }
            Task { @MainActor in self?.handleDeviceToken(data) }
        }

        NotificationCenter.default.addObserver(
            forName: .apnsRegistrationFailed,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let error = note.object as? NSError
            Task { @MainActor in
                self?.handleRegistrationError(error ?? NSError(domain: "APNs", code: -1))
            }
        }
    }

    // MARK: - Authorization

    /// 現在の通知権限を読む。
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .authorized
        @unknown default: .notDetermined
        }
    }

    /// 通知許可ダイアログを出す。初回のみ効果あり、以降は Settings app で切り替え。
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await refreshAuthorizationStatus()
        } catch {
            registrationError = "通知権限の取得に失敗しました"
            pushLogger.error("authorization request failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Device token

    /// AppDelegate から NotificationCenter 経由で受信。token を hex に変換して Supabase に保存。
    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        Task { await saveToken(token) }
    }

    func handleRegistrationError(_ error: Error) {
        registrationError = "デバイス登録に失敗しました"
        pushLogger.error("APNs registration failed: \(String(describing: error), privacy: .public)")
    }

    // MARK: - Supabase upsert + retry

    /// `user_device_tokens` テーブルに upsert (user_id + token ペア)。
    /// RLS は `(select auth.uid()) = user_id` で保護される。
    /// 失敗時は UserDefaults に pending として保持 → 次回起動・次回 auth change で再送。
    private func saveToken(_ token: String) async {
        do {
            let session = try await client.auth.session
            try await client
                .from("user_device_tokens")
                .upsert(
                    [
                        "user_id": session.user.id.uuidString,
                        "token": token,
                        "platform": "ios"
                    ],
                    onConflict: "user_id,token"
                )
                .execute()
            clearPendingToken()
            pushLogger.debug("APNs token saved to Supabase")
        } catch {
            pushLogger.error("token save failed, queued for retry: \(String(describing: error), privacy: .public)")
            stashPendingToken(token)
        }
    }

    /// Pending token persistence (idempotent upsert + 単一値保持で衝突なし)。
    private func stashPendingToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: pendingTokenKey)
    }

    private func clearPendingToken() {
        UserDefaults.standard.removeObject(forKey: pendingTokenKey)
    }

    /// init 時 / auth state 変化時に呼び出し可能な retry 入口。
    /// - 認証未完了 (session 取得失敗) なら何もしない (次のサインイン時に再試行)
    /// - pending が無ければ no-op
    func retryPendingTokenSaveIfAny() async {
        guard let pending = UserDefaults.standard.string(forKey: pendingTokenKey) else { return }
        await saveToken(pending)
    }
}
