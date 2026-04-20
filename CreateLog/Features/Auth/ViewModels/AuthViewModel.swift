import Foundation
import AuthenticationServices
import CryptoKit
import OSLog

/// 認証画面のViewModel
@MainActor @Observable
final class AuthViewModel {
    @ObservationIgnored
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "Auth")

    // MARK: - State

    var authState: AuthState = .unknown
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored private let authService: any AuthServiceProtocol
    @ObservationIgnored private var currentNonce: String?
    /// logout / deleteAccount 成功時の SwiftData cache clear + DomainContext reset + event publish を担う。
    /// preview/test で nil 注入可能 (cleanup skip)。
    @ObservationIgnored private let cleanupService: AuthCleanupService?

    /// explicit `signOut()` / `deleteAccount()` 経由で cleanup を実行したら true。
    /// Supabase SDK が遅れて authStateChanges の `.signedOut` を yield しても、
    /// observeAuthState での補完 cleanup を 1 回だけ skip するフラグ。
    /// 二重 `.sessionCleared` publish → Feed の posts 2 回 reset の race を防ぐ。
    @ObservationIgnored private var skipNextAutoCleanup = false

    init(authService: any AuthServiceProtocol, cleanupService: AuthCleanupService? = nil) {
        self.authService = authService
        self.cleanupService = cleanupService
        Self.logger.debug("init: authService type = \(String(describing: type(of: authService)), privacy: .public)")
    }

    #if DEBUG
    /// dev bypass: i18n 等の UI 検証で OAuth login せず MainTab を表示させるための強制 authenticated。
    /// UserDefaults "devBypassAuth" = true で `observeAuthState()` 前に呼ぶ。Supabase session は無いので
    /// データ fetch は 401 になるが画面レイアウト / 翻訳の検証には十分。
    func devForceAuthenticated(userId: String = "00000000-0000-0000-0000-000000000dev") {
        authState = .authenticated(userId: userId)
    }
    #endif

    // MARK: - Auth State Observation

    func observeAuthState() async {
        authState = await authService.currentState
        // 初回 state 取得時に currentUserId を set (既ログイン状態で起動した時の first paint 用)。
        syncCurrentUserId(from: authState)

        for await state in authService.observeAuthChanges() {
            let wasAuthenticated: Bool = {
                if case .authenticated = authState { return true }
                return false
            }()
            authState = state

            // authenticated 遷移時: currentUserId を set して全 VM に共有 (MEDIUM #8)。
            syncCurrentUserId(from: state)

            // session expiry 自動伝播 (HIGH): 明示的 signOut() を経由せず server 側で session が
            // 切れた場合 (refresh token 失効など) のみ cleanup 補完する。
            // 明示 signOut()/deleteAccount() で既に cleanup 済ならフラグ guard で skip し、
            // .sessionCleared の二重 publish を防ぐ (HIGH #2)。
            if wasAuthenticated, case .unauthenticated = state {
                if skipNextAutoCleanup {
                    skipNextAutoCleanup = false
                } else {
                    cleanupService?.performCleanup()
                }
            }
        }
    }

    /// authState から UUID を取り出し DomainContext に反映。
    private func syncCurrentUserId(from state: AuthState) {
        switch state {
        case .authenticated(let userIdString):
            cleanupService?.setCurrentUserId(UUID(uuidString: userIdString))
        case .unauthenticated, .unknown:
            // unauthenticated は performCleanup 側で reset 済、unknown は初期化前なので触らない。
            break
        }
    }

    // MARK: - Sign in with Apple

    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
        return request
    }

    /// Apple Sign In を実行。session 確立まで確認できた時だけ true を返す。
    /// 呼出側はこの戻り値で遷移判定する (`authState` の AsyncStream 反映を待たない)。
    @discardableResult
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = String(localized: "auth.error.appleCredential")
                return false
            }
            do {
                let userId = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                authState = .authenticated(userId: userId)
                Self.logger.info("Apple sign in success (user.id=\(userId, privacy: .private))")
                guard await verifySessionEstablished(provider: "apple") else {
                    try? await authService.signOut()
                    authState = .unauthenticated
                    errorMessage = String(localized: "auth.error.sessionFailed")
                    return false
                }
                return true
            } catch {
                Self.logger.error("Apple sign in failed: \(error.localizedDescription, privacy: .private)")
                errorMessage = mapErrorMessage(error)
                return false
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return false
            }
            Self.logger.error("Apple authorization failed: \(error.localizedDescription, privacy: .private)")
            errorMessage = String(localized: "auth.error.appleFailed")
            return false
        }
    }

    /// サインイン成功後に実 session が SDK storage に書き込まれたか確認する。
    /// 書込み完了前に displayName step に進むと `Auth session missing` になるため、
    /// ここで最大 3 秒待って session 確立できなければ失敗扱いにする。
    private func verifySessionEstablished(provider: String) async -> Bool {
        for attempt in 0..<12 {
            let state = await authService.currentState
            if case .authenticated = state {
                Self.logger.info("Session verified after \(attempt, privacy: .public) retries (provider=\(provider, privacy: .public))")
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        Self.logger.warning("Session NOT established after 3s (provider=\(provider, privacy: .public))")
        return false
    }

    // MARK: - Sign in with Google (OAuth web flow)

    /// T5 (2026-04-12): Google OAuth web flow ハンドラ。
    /// SDK 内部で ASWebAuthenticationSession 起動 → callback → session 確立。
    /// user cancel は silent return (errorMessage を触らない、X/Instagram UX 踏襲)。
    @discardableResult
    func handleGoogleSignIn() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let userId = try await authService.signInWithGoogleOAuth()
            authState = .authenticated(userId: userId)
            Self.logger.info("Google sign in success (user.id=\(userId, privacy: .private))")
            guard await verifySessionEstablished(provider: "google") else {
                try? await authService.signOut()
                authState = .unauthenticated
                errorMessage = String(localized: "auth.error.sessionFailed")
                return false
            }
            return true
        } catch {
            if Self.isUserCancel(error) { return false }
            Self.logger.error("Google sign in failed: \(error.localizedDescription, privacy: .private)")
            errorMessage = mapErrorMessage(error)
            return false
        }
    }

    // MARK: - Sign in with GitHub (OAuth web flow)

    /// T5 (2026-04-12): GitHub OAuth web flow ハンドラ。
    /// scopes: user:email + read:user。user cancel は silent return。
    @discardableResult
    func handleGitHubSignIn() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let userId = try await authService.signInWithGitHub()
            authState = .authenticated(userId: userId)
            Self.logger.info("GitHub sign in success (user.id=\(userId, privacy: .private))")
            guard await verifySessionEstablished(provider: "github") else {
                try? await authService.signOut()
                authState = .unauthenticated
                errorMessage = String(localized: "auth.error.sessionFailed")
                return false
            }
            return true
        } catch {
            if Self.isUserCancel(error) { return false }
            Self.logger.error("GitHub sign in failed: \(error.localizedDescription, privacy: .private)")
            errorMessage = mapErrorMessage(error)
            return false
        }
    }

    /// ASWebAuthenticationSession の user cancel 検出
    private nonisolated static func isUserCancel(_ error: Error) -> Bool {
        let nsError = error as NSError
        // ASWebAuthenticationSessionError.canceledLogin = 1
        if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
            return true
        }
        return false
    }

    // MARK: - Sign Out

    /// logout 成功時:
    /// 1. SupabaseAuth から session 解除
    /// 2. `cleanupService` が SwiftData cache 全削除 + DomainContext reset + `.sessionCleared` publish
    /// 3. `authState = .unauthenticated` で rootView を即 onboarding に切替
    ///    (observeAuthChanges の遅延を待たず同期切替、AccountSettings から残画面が残るバグを防ぐ)
    /// 4. `skipNextAutoCleanup = true` で Supabase SDK 遅延 `.signedOut` yield 時の二重 cleanup を防止
    func signOut() async {
        do {
            try await authService.signOut()
            skipNextAutoCleanup = true
            cleanupService?.performCleanup()
            authState = .unauthenticated
        } catch {
            errorMessage = mapErrorMessage(error)
        }
    }

    // MARK: - Delete Account

    /// Edge Function 経由で auth.user + profile を cascade 削除し、最後に signOut する。
    /// 失敗時は errorMessage を立てて state は変えない (リトライ可能)。
    /// 成功時は signOut と同様に cleanup + authState 更新で rootView を onboarding へ戻す。
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.deleteAccount()
            skipNextAutoCleanup = true
            cleanupService?.performCleanup()
            authState = .unauthenticated
        } catch {
            errorMessage = mapErrorMessage(error)
        }
    }

    // MARK: - Current user info

    /// AccountSettingsView 用の email + 連携プロバイダ取得。
    /// observeAuthState() が走ってなくても単発で取れる。
    func loadCurrentUserInfo() async -> CurrentUserInfo? {
        await authService.currentUserInfo
    }

    // MARK: - Helpers

    private func mapErrorMessage(_ error: Error) -> String {
        guard let authError = error as? AuthError else {
            return "予期しないエラーが発生しました"
        }
        return switch authError {
        case .invalidCredentials: "メールアドレスまたはパスワードが正しくありません"
        case .networkError: "ネットワークに接続できません"
        case .userNotFound: "アカウントが見つかりません"
        case .emailAlreadyInUse: "このメールアドレスは既に使用されています"
        case .weakPassword: "パスワードが簡単すぎます"
        // 内部エラーメッセージはUIに出さない (情報漏洩対策)
        case .unknown: "予期しないエラーが発生しました。しばらくしてから再試行してください"
        }
    }

    /// Apple公式のrejection samplingパターンでnonceを生成 (バイアスなし)
    private nonisolated func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result: [Character] = []
        var remaining = length

        while remaining > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            precondition(status == errSecSuccess, "Failed to generate random bytes")

            for random in randomBytes where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return String(result)
    }

    private nonisolated func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
