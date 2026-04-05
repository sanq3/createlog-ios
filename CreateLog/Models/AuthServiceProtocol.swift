import Foundation

/// 認証状態
enum AuthState: Equatable, Sendable {
    case unknown
    case unauthenticated
    case authenticated(userId: String)
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
    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws -> String
    /// Sign in with Google
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> String
}

/// Email+パスワード認証
protocol EmailAuthProtocol: Sendable {
    /// メール+パスワードでサインアップ
    func signUp(email: String, password: String) async throws -> String
    /// メール+パスワードでサインイン
    func signIn(email: String, password: String) async throws -> String
}

/// セッション管理
protocol AuthSessionProtocol: Sendable {
    /// 現在の認証状態を取得
    var currentState: AuthState { get async }
    /// サインアウト
    func signOut() async throws
    /// アカウント削除
    func deleteAccount() async throws
    /// 認証状態の変更を監視
    func observeAuthChanges() -> AsyncStream<AuthState>
}

/// 認証サービスの統合プロトコル (全認証機能を提供する実装用)
typealias AuthServiceProtocol = OAuthSignInProtocol & EmailAuthProtocol & AuthSessionProtocol
