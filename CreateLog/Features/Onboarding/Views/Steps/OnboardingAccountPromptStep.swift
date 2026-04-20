import SwiftUI
import AuthenticationServices

/// Step 08: アカウント作成 / ログイン。Apple / Google / GitHub Sign In を実接続。
/// isLoginMode で新規作成モード (デフォルト) とログインモード (Welcome のログインリンク経由) を切替。
struct OnboardingAccountPromptStep: View {
    let projectName: String
    let platform: String
    let isLoginMode: Bool
    @Bindable var authViewModel: AuthViewModel
    let onAdvance: () -> Void
    let onBackToWelcome: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    private var titleKey: LocalizedStringKey {
        isLoginMode ? "onboarding.account.title.login" : "onboarding.account.title.signup"
    }

    private func providerButtonKey(_ provider: String) -> LocalizedStringKey {
        isLoginMode
            ? "onboarding.account.button.login \(provider)"
            : "onboarding.account.button.signup \(provider)"
    }

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                Text(titleKey)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                if !isLoginMode {
                    Spacer().frame(height: 28)

                    // Compact service card (新規モードのみ)
                    HStack(spacing: 14) {
                        Text(String(projectName.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Self.iconColor(for: projectName))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(projectName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.clTextPrimary)
                                .lineLimit(1)
                            Text(platform)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.clSurfaceHigh)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 40)
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.95)
                }

                Spacer()

                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }

                // Auth buttons (3ボタン完全同一UI: Capsule + 透過 bg + 黒枠 + SF/Canvas アイコン + 統一 font)
                VStack(spacing: 12) {
                    AppleSignInButton(
                        labelText: providerButtonKey("Apple"),
                        onRequest: { request in
                            let prepared = authViewModel.prepareAppleSignIn()
                            request.requestedScopes = prepared.requestedScopes
                            request.nonce = prepared.nonce
                        },
                        onCompletion: { result in
                            Task { @MainActor in
                                if await authViewModel.handleAppleSignIn(result: result) {
                                    onAdvance()
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 32)

                    Button {
                        Task { @MainActor in
                            if await authViewModel.handleGoogleSignIn() {
                                onAdvance()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image("GoogleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text(providerButtonKey("Google"))
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
                    .padding(.horizontal, 32)

                    Button {
                        Task { @MainActor in
                            if await authViewModel.handleGitHubSignIn() {
                                onAdvance()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image("GitHubLogo")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(Color.clTextPrimary)
                            Text(providerButtonKey("GitHub"))
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
                    .padding(.horizontal, 32)

                    if isLoginMode {
                        Button {
                            HapticManager.light()
                            onBackToWelcome()
                        } label: {
                            HStack(spacing: 4) {
                                Text("onboarding.account.signupPrefix")
                                    .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                                Text("onboarding.account.signupLink")
                                    .foregroundStyle(Color.clTextPrimary.opacity(0.85))
                                    .underline()
                            }
                            .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
                .padding(.bottom, 44)
            }

            // Loading overlay
            if authViewModel.isLoading {
                Color.clBackground.opacity(0.7)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(Color.clTextPrimary)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    cardVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    ctaVisible = true
                }
            }
        }
    }
}

// MARK: - Icon Color

extension OnboardingAccountPromptStep {
    /// 純粋関数 (String → Color) のため `nonisolated` 明示。PhotosPicker の @Sendable label
    /// closure などから呼べるように MainActor 隔離を外す。
    nonisolated static func iconColor(for name: String) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.20, 0.25, 0.45), (0.25, 0.15, 0.35), (0.15, 0.20, 0.32),
            (0.18, 0.28, 0.25), (0.28, 0.18, 0.22), (0.22, 0.22, 0.35),
        ]
        let index = abs(name.hashValue) % palette.count
        let (r, g, b) = palette[index]
        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    OnboardingAccountPromptStep(
        projectName: "つくろぐ",
        platform: "iOS",
        isLoginMode: false,
        authViewModel: AuthViewModel(authService: NoOpAuthService()),
        onAdvance: {},
        onBackToWelcome: {}
    )
}
