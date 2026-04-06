import Foundation
@testable import CreateLog

/// テスト用のモックAuthService
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    // MARK: - Stub responses

    var stubbedState: AuthState = .unauthenticated
    var stubbedUserId: String = "test-user-id"
    var stubbedError: Error?
    var signOutCalled = false
    var deleteAccountCalled = false

    // MARK: - AuthServiceProtocol

    var currentState: AuthState {
        get async { stubbedState }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> String {
        if let error = stubbedError { throw error }
        stubbedState = .authenticated(userId: stubbedUserId)
        return stubbedUserId
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> String {
        if let error = stubbedError { throw error }
        stubbedState = .authenticated(userId: stubbedUserId)
        return stubbedUserId
    }

    func signUp(email: String, password: String) async throws -> String {
        if let error = stubbedError { throw error }
        stubbedState = .authenticated(userId: stubbedUserId)
        return stubbedUserId
    }

    func signIn(email: String, password: String) async throws -> String {
        if let error = stubbedError { throw error }
        stubbedState = .authenticated(userId: stubbedUserId)
        return stubbedUserId
    }

    func signOut() async throws {
        if let error = stubbedError { throw error }
        signOutCalled = true
        stubbedState = .unauthenticated
    }

    func deleteAccount() async throws {
        if let error = stubbedError { throw error }
        deleteAccountCalled = true
        stubbedState = .unauthenticated
    }

    func observeAuthChanges() -> AsyncStream<AuthState> {
        AsyncStream { continuation in
            continuation.yield(stubbedState)
            continuation.finish()
        }
    }
}
