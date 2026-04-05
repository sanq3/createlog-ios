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

    // Email form
    var email = ""
    var password = ""
    var isSignUpMode = false

    // MARK: - Dependencies

    @ObservationIgnored private let authService: any AuthServiceProtocol
    @ObservationIgnored private var currentNonce: String?

    init(authService: any AuthServiceProtocol) {
        self.authService = authService
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

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple認証情報の取得に失敗しました"
                return
            }
            do {
                _ = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                errorMessage = mapErrorMessage(error)
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = "Apple認証に失敗しました"
        }
    }

    // MARK: - Email Auth

    func signInWithEmail() async {
        guard validateEmailForm() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isSignUpMode {
                _ = try await authService.signUp(email: email, password: password)
            } else {
                _ = try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = mapErrorMessage(error)
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = mapErrorMessage(error)
        }
    }

    // MARK: - Validation

    private func validateEmailForm() -> Bool {
        errorMessage = nil
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            return false
        }
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "有効なメールアドレスを入力してください"
            return false
        }
        guard password.count >= 8 else {
            errorMessage = "パスワードは8文字以上で入力してください"
            return false
        }
        return true
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
