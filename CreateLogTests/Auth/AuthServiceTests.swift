import Testing
@testable import CreateLog

@Suite("AuthService")
struct AuthServiceTests {

    // MARK: - Initial State

    @Test("初期状態はunauthenticated")
    func initialState() async {
        let service = MockAuthService()
        let state = await service.currentState
        #expect(state == .unauthenticated)
    }

    // MARK: - Email Sign Up

    @Test("メールサインアップでuserIdが返る")
    func signUpReturnsUserId() async throws {
        let service = MockAuthService()
        service.stubbedUserId = "new-user-123"

        let userId = try await service.signUp(email: "test@example.com", password: "password123")

        #expect(userId == "new-user-123")
        let state = await service.currentState
        #expect(state == .authenticated(userId: "new-user-123"))
    }

    @Test("メールサインアップ失敗でエラーがthrowされる")
    func signUpThrowsOnError() async {
        let service = MockAuthService()
        service.stubbedError = AuthError.invalidCredentials

        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signUp(email: "bad@example.com", password: "short")
        }
    }

    // MARK: - Email Sign In

    @Test("メールサインインでauthenticatedになる")
    func signInChangesState() async throws {
        let service = MockAuthService()
        service.stubbedUserId = "existing-user-456"

        _ = try await service.signIn(email: "test@example.com", password: "password123")

        let state = await service.currentState
        #expect(state == .authenticated(userId: "existing-user-456"))
    }

    @Test("メールサインイン失敗でエラー")
    func signInThrowsOnError() async {
        let service = MockAuthService()
        service.stubbedError = AuthError.invalidCredentials

        await #expect(throws: AuthError.invalidCredentials) {
            try await service.signIn(email: "wrong@example.com", password: "wrong")
        }
    }

    // MARK: - Sign Out

    @Test("サインアウトでunauthenticatedになる")
    func signOutChangesState() async throws {
        let service = MockAuthService()
        service.stubbedState = .authenticated(userId: "user-123")

        try await service.signOut()

        let state = await service.currentState
        #expect(state == .unauthenticated)
        #expect(service.signOutCalled)
    }

    // MARK: - Delete Account

    @Test("アカウント削除でunauthenticatedになる")
    func deleteAccountChangesState() async throws {
        let service = MockAuthService()
        service.stubbedState = .authenticated(userId: "user-123")

        try await service.deleteAccount()

        let state = await service.currentState
        #expect(state == .unauthenticated)
        #expect(service.deleteAccountCalled)
    }

    // MARK: - Apple Sign In

    @Test("AppleサインインでuserIdが返る")
    func appleSignInReturnsUserId() async throws {
        let service = MockAuthService()
        service.stubbedUserId = "apple-user-789"

        let userId = try await service.signInWithApple(idToken: "valid-token", nonce: "nonce")

        #expect(userId == "apple-user-789")
    }

    // MARK: - Google Sign In

    @Test("GoogleサインインでuserIdが返る")
    func googleSignInReturnsUserId() async throws {
        let service = MockAuthService()
        service.stubbedUserId = "google-user-012"

        let userId = try await service.signInWithGoogle(idToken: "google-token", accessToken: "access-token")

        #expect(userId == "google-user-012")
    }

    // MARK: - Auth State Observation

    @Test("認証状態の変更をストリームで受信できる")
    func observeAuthChanges() async {
        let service = MockAuthService()
        service.stubbedState = .authenticated(userId: "stream-user")

        var states: [AuthState] = []
        for await state in service.observeAuthChanges() {
            states.append(state)
        }

        #expect(states == [.authenticated(userId: "stream-user")])
    }
}
