import SwiftUI
import AuthenticationServices

/// ログイン画面
struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo + Title (タイポグラフィのみ、記号・アイコン不使用)
            VStack(spacing: 12) {
                Text("つくろぐ")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(2)

                Text("エンジニアのための\n作業記録プラットフォーム")
                    .font(.subheadline)
                    .foregroundStyle(Color.clTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Auth Buttons
            VStack(spacing: 12) {
                // Sign in with Apple (Apple HIGで必須)
                SignInWithAppleButton(.signIn) { request in
                    let appleRequest = viewModel.prepareAppleSignIn()
                    request.requestedScopes = appleRequest.requestedScopes
                    request.nonce = appleRequest.nonce
                } onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignIn(result: result)
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .disabled(viewModel.isLoading)

            Spacer()
                .frame(height: 40)
        }
        .background(Color.clBackground)
    }
}
