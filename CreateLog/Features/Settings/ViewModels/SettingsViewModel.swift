import Foundation

/// 設定画面のViewModel
@MainActor @Observable
final class SettingsViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let authService: any AuthServiceProtocol
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol

    // MARK: - State

    var profile: ProfileDTO?
    var isLoading = false
    var errorMessage: String?
    var showDeleteConfirmation = false
    var isSignedOut = false

    // MARK: - Init

    init(authService: any AuthServiceProtocol, profileRepository: any ProfileRepositoryProtocol) {
        self.authService = authService
        self.profileRepository = profileRepository
    }

    // MARK: - Actions

    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await profileRepository.fetchMyProfile()
        } catch {
            // 未ログイン状態はエラーにしない
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
            isSignedOut = true
        } catch {
            errorMessage = String(localized: "auth.error.logout")
        }
    }

    func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.deleteAccount()
            isSignedOut = true
        } catch {
            errorMessage = String(localized: "auth.error.deleteFailed")
        }
    }
}
