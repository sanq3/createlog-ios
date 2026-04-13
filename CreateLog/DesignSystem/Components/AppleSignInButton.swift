import SwiftUI
import AuthenticationServices

/// Apple Sign In 完全自作 Button。`SignInWithAppleButton` (SwiftUI) や
/// `ASAuthorizationAppleIDButton` (UIKit) は shape / 背景を制御できないため、
/// Google / GitHub ボタンと完全同一 UI にするために自作する。
///
/// Apple HIG の要件 (apple.logo + 指定文言 + 黒/白 の foreground) は満たしつつ、
/// Capsule + 透過背景 + 黒枠 outline で他 OAuth ボタンと揃える。
struct AppleSignInButton: View {
    let labelText: String
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    @State private var coordinator: Coordinator?

    var body: some View {
        Button {
            startAuthorization()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary)
                Text(labelText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule()
                    .strokeBorder(Color.clTextPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func startAuthorization() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        onRequest(request)
        let c = Coordinator(onCompletion: onCompletion)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = c
        controller.presentationContextProvider = c
        coordinator = c
        controller.performRequests()
    }

    @MainActor
    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            onCompletion(.success(authorization))
        }

        func authorizationController(
            controller: ASAuthorizationController,
            didCompleteWithError error: Error
        ) {
            onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
