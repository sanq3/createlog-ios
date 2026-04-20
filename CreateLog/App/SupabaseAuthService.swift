import Foundation
import Supabase
import Auth
import AuthenticationServices
import OSLog

/// Supabaseを使った認証サービスの実装
final class SupabaseAuthService: AuthServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "Auth")
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// `signInWithIdToken` / `signInWithOAuth` が Session を返しても、
    /// まれに SDK storage 反映が読めないことがあるため最後に明示的に検証する。
    /// 初回失敗時は返却された token から `setSession` を再実行して復旧を試みる。
    ///
    /// 2026-04-20 (security): print → os.Logger、user.id / session 内容は `privacy: .private` で
    /// redacted。token / email は一切 log しない (production stderr / syslog / MDM から見えるため)。
    private func ensureSessionEstablished(
        from session: Session,
        provider: String
    ) async {
        for attempt in 0..<4 {
            do {
                _ = try await client.auth.session
                Self.logger.info("persisted session verified (provider=\(provider, privacy: .public), attempt=\(attempt, privacy: .public))")
                return
            } catch {
                Self.logger.warning("persisted session verify failed (provider=\(provider, privacy: .public), attempt=\(attempt + 1, privacy: .public)): \(error.localizedDescription, privacy: .private)")
                if attempt == 0 {
                    do {
                        _ = try await client.auth.setSession(
                            accessToken: session.accessToken,
                            refreshToken: session.refreshToken
                        )
                        Self.logger.info("setSession recovery succeeded (provider=\(provider, privacy: .public))")
                    } catch {
                        Self.logger.error("setSession recovery failed (provider=\(provider, privacy: .public)): \(error.localizedDescription, privacy: .private)")
                    }
                }

                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }

        Self.logger.error("persisted session unavailable after recovery attempts (provider=\(provider, privacy: .public))")
    }

    var currentState: AuthState {
        get async {
            do {
                let session = try await client.auth.session
                return .authenticated(userId: session.user.id.uuidString)
            } catch {
                return .unauthenticated
            }
        }
    }

    var currentUserInfo: CurrentUserInfo? {
        get async {
            guard let session = try? await client.auth.session else { return nil }
            let providers: [String] = session.user.identities?.map { $0.provider.lowercased() } ?? []
            return CurrentUserInfo(
                userId: session.user.id.uuidString,
                email: session.user.email,
                linkedProviders: Array(Set(providers)).sorted()
            )
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> String {
        Self.logger.info("signInWithApple called")
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            let userIdStr = session.user.id.uuidString
            Self.logger.info("signInWithIdToken returned (provider=apple, user.id=\(userIdStr, privacy: .private))")

            // session storage 反映の即時検証
            do {
                _ = try await client.auth.session
                Self.logger.info("post-signIn session verify OK")
            } catch {
                Self.logger.error("post-signIn session verify failed: \(error.localizedDescription, privacy: .private)")
            }

            await ensureSessionEstablished(from: session, provider: "apple")

            return userIdStr
        } catch {
            Self.logger.error("signInWithIdToken threw \(String(describing: type(of: error)), privacy: .public): \(error.localizedDescription, privacy: .private)")
            throw mapError(error)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> String {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
            )
            return session.user.id.uuidString
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - T5: OAuth web flow

    /// Google OAuth (web flow)。
    /// Supabase SDK が内部で ASWebAuthenticationSession を起動し、
    /// OAuth consent → callback URL で session を直接返す。
    /// `prefersEphemeralWebBrowserSession = true` で既存 Safari session を使わず fresh auth を強制。
    func signInWithGoogleOAuth() async throws -> String {
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "createlog://auth-callback"),
                scopes: "openid email profile"
            ) { webSession in
                webSession.prefersEphemeralWebBrowserSession = true
            }
            await ensureSessionEstablished(from: session, provider: "google")
            return session.user.id.uuidString
        } catch {
            throw mapError(error)
        }
    }

    /// GitHub OAuth (web flow)。
    /// GitHub は OpenID Connect 非対応のため idToken 経路は使えない、web flow 一択。
    /// scopes: `user:email` (email 取得) + `read:user` (profile 取得)。
    func signInWithGitHub() async throws -> String {
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .github,
                redirectTo: URL(string: "createlog://auth-callback"),
                scopes: "user:email read:user"
            ) { webSession in
                webSession.prefersEphemeralWebBrowserSession = true
            }
            await ensureSessionEstablished(from: session, provider: "github")
            return session.user.id.uuidString
        } catch {
            throw mapError(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw mapError(error)
        }
    }

    func deleteAccount() async throws {
        // アカウント削除はEdge Function経由で実行（service_roleが必要なため）。
        // delete 成功後の signOut は `try?` で swallow する。
        // Reference: https://github.com/supabase/auth/issues/1801 — delete 後の signOut は
        // サーバー側で「User from sub claim in JWT does not exist」エラーを返す既知バグ。
        // このエラーを throw すると UI には「削除失敗」と見えるが実際は削除成功しており UX が壊れる。
        // Supabase Swift SDK は signOut 失敗時もローカル Keychain を確実にクリアするので
        // session は確実に消える。delete 自体が失敗した場合は catch で throw する (session 維持でリトライ可能)。
        do {
            let session = try await client.auth.session
            try await client.functions.invoke(
                "delete-account",
                options: .init(body: ["user_id": session.user.id.uuidString])
            )
            try? await client.auth.signOut()
        } catch {
            throw mapError(error)
        }
    }

    func observeAuthChanges() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    case .signedIn, .tokenRefreshed:
                        if let session {
                            continuation.yield(.authenticated(userId: session.user.id.uuidString))
                        }
                    case .signedOut:
                        continuation.yield(.unauthenticated)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid") || message.contains("credentials") {
            return .invalidCredentials
        }
        if message.contains("not found") || message.contains("no user") {
            return .userNotFound
        }
        if message.contains("already") || message.contains("exists") {
            return .emailAlreadyInUse
        }
        if message.contains("weak") || message.contains("password") {
            return .weakPassword
        }
        if message.contains("network") || message.contains("connection") {
            return .networkError
        }
        return .unknown(error.localizedDescription)
    }
}
