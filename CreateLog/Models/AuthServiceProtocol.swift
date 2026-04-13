import Foundation

/// 認証状態
enum AuthState: Equatable, Sendable {
    case unknown
    case unauthenticated
    case authenticated(userId: String)
}

/// 現在ユーザーの概要 (AccountSettings 表示用)。
/// `email` は外部 IdP 経由だと nil 可能性あり。
/// `linkedProviders` は Supabase の `identities[].provider` を小文字文字列で保持。
struct CurrentUserInfo: Equatable, Sendable {
    let userId: String
    let email: String?
    let linkedProviders: [String]
}

/// 認証エラー
enum AuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case networkError
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case unknown(String)
}

/// 外部プロバイダ経由のサインイン (Apple/Google/GitHub等)
protocol OAuthSignInProtocol: Sendable {
    /// Sign in with Apple (native ID token flow)
    func signInWithApple(idToken: String, nonce: String) async throws -> String
    /// Sign in with Google (legacy GoogleSignIn SDK 経由、現在 UI から未使用)
    /// T5 以降は `signInWithGoogleOAuth()` (web flow) を使う。Phase 2 で削除判断。
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> String
    /// T5 (2026-04-12): OAuth web flow (Google)
    /// Supabase SDK の signInWithOAuth + ASWebAuthenticationSession で完結。
    /// GoogleSignIn SDK 依存なし、prefersEphemeralWebBrowserSession = true で privacy 優先。
    func signInWithGoogleOAuth() async throws -> String
    /// T5 (2026-04-12): OAuth web flow (GitHub)
    /// GitHub は OpenID Connect 非対応のため idToken 経路は使えない、web flow 一択。
    func signInWithGitHub() async throws -> String
}

/// Email+パスワード認証
protocol EmailAuthProtocol: Sendable {
    /// メール+パスワードでサインアップ
    func signUp(email: String, password: String) async throws -> String
    /// メール+パスワードでサインイン
    func signIn(email: String, password: String) async throws -> String
    /// パスワードリセット用メール送信
    func sendPasswordResetEmail(to email: String) async throws
}

/// セッション管理
protocol AuthSessionProtocol: Sendable {
    /// 現在の認証状態を取得
    var currentState: AuthState { get async }
    /// 現在ユーザーの詳細 (メール + 連携プロバイダ)。未ログイン時 nil
    var currentUserInfo: CurrentUserInfo? { get async }
    /// サインアウト
    func signOut() async throws
    /// アカウント削除
    func deleteAccount() async throws
    /// 認証状態の変更を監視
    func observeAuthChanges() -> AsyncStream<AuthState>
}

/// 認証サービスの統合プロトコル (全認証機能を提供する実装用)
typealias AuthServiceProtocol = OAuthSignInProtocol & EmailAuthProtocol & AuthSessionProtocol

/// Preview / 未接続時用の NoOp 実装
final class NoOpAuthService: AuthServiceProtocol {
    private func runtimeUsageError(_ function: StaticString = #function) -> AuthError {
        .unknown("NoOpAuthService(\(function)) が実行されました。Preview/未接続専用のため、本番画面に注入しないでください。")
    }

    var currentState: AuthState { get async { .unauthenticated } }
    var currentUserInfo: CurrentUserInfo? { get async { nil } }
    func signInWithApple(idToken: String, nonce: String) async throws -> String { throw runtimeUsageError() }
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> String { throw runtimeUsageError() }
    func signInWithGoogleOAuth() async throws -> String { throw runtimeUsageError() }
    func signInWithGitHub() async throws -> String { throw runtimeUsageError() }
    func signUp(email: String, password: String) async throws -> String { throw runtimeUsageError() }
    func signIn(email: String, password: String) async throws -> String { throw runtimeUsageError() }
    func sendPasswordResetEmail(to email: String) async throws { throw runtimeUsageError() }
    func signOut() async throws { throw runtimeUsageError() }
    func deleteAccount() async throws { throw runtimeUsageError() }
    func observeAuthChanges() -> AsyncStream<AuthState> { AsyncStream { $0.finish() } }
}
