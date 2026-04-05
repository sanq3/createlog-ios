import Foundation
import Supabase
import Auth

/// Supabaseを使った認証サービスの実装
final class SupabaseAuthService: AuthServiceProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
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

    func signInWithApple(idToken: String, nonce: String) async throws -> String {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            return session.user.id.uuidString
        } catch {
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

    func signUp(email: String, password: String) async throws -> String {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            guard let session = response.session else {
                throw AuthError.unknown("No session returned after sign up")
            }
            return session.user.id.uuidString
        } catch let error as AuthError {
            throw error
        } catch {
            throw mapError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> String {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
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
        // アカウント削除はEdge Function経由で実行（service_roleが必要なため）
        do {
            let session = try await client.auth.session
            try await client.functions.invoke(
                "delete-account",
                options: .init(body: ["user_id": session.user.id.uuidString])
            )
            try await client.auth.signOut()
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
