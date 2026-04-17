import Foundation
import AuthenticationServices
import CryptoKit

/// 認証画面のViewModel
@MainActor @Observable
final class AuthViewModel {
    // MARK: - State

    var authState: AuthState = .unknown
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    @ObservationIgnored private let authService: any AuthServiceProtocol
    @ObservationIgnored private var currentNonce: String?

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
        print("[AuthViewModel] 🔧 init: authService type = \(type(of: authService))")
    }

    // MARK: - Auth State Observation

    func observeAuthState() async {
        authState = await authService.currentState
        for await state in authService.observeAuthChanges() {
            authState = state
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
                print("[AuthViewModel] ✅ Apple sign in success: userId=\(userId)")
                guard await verifySessionEstablished(provider: "apple") else {
                    try? await authService.signOut()
                    authState = .unauthenticated
                    errorMessage = String(localized: "auth.error.sessionFailed")
                    return false
                }
                return true
            } catch {
                print("[AuthViewModel] ❌ Apple sign in failed: \(error)")
                errorMessage = mapErrorMessage(error)
                return false
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return false
            }
            print("[AuthViewModel] ❌ Apple authorization failed: \(error)")
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
                print("[AuthViewModel] ✅ Session verified after \(attempt) retries (provider=\(provider))")
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        print("[AuthViewModel] ⚠️ Session NOT established after 3s (provider=\(provider)). 次 step で Auth session missing の可能性あり")
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
            print("[AuthViewModel] ✅ Google sign in success: userId=\(userId)")
            guard await verifySessionEstablished(provider: "google") else {
                try? await authService.signOut()
                authState = .unauthenticated
                errorMessage = String(localized: "auth.error.sessionFailed")
                return false
            }
            return true
        } catch {
            if Self.isUserCancel(error) { return false }
            print("[AuthViewModel] ❌ Google sign in failed: \(error)")
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
            print("[AuthViewModel] ✅ GitHub sign in success: userId=\(userId)")
            guard await verifySessionEstablished(provider: "github") else {
                try? await authService.signOut()
                authState = .unauthenticated
                errorMessage = String(localized: "auth.error.sessionFailed")
                return false
            }
            return true
        } catch {
            if Self.isUserCancel(error) { return false }
            print("[AuthViewModel] ❌ GitHub sign in failed: \(error)")
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

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = mapErrorMessage(error)
        }
    }

    // MARK: - Delete Account

    /// Edge Function 経由で auth.user + profile を cascade 削除し、最後に signOut する。
    /// 失敗時は errorMessage を立てて state は変えない (リトライ可能)。
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.deleteAccount()
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
