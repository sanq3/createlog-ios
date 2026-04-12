import SwiftUI
import AuthenticationServices

/// Step 08: アカウント作成促進。Apple / Google Sign In を実接続。
/// 認証成功 → onAdvance。スキップ → onSkip (オンボーディング完了)。
struct OnboardingAccountPromptStep: View {
    let projectName: String
    let platform: String
    @Bindable var authViewModel: AuthViewModel
    let onAdvance: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                Text("アカウントを作成して\nデータを安全に保存")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 28)

                // Compact service card
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

                // Auth buttons
                VStack(spacing: 12) {
                    // Sign in with Apple (dark mode = .black で bg に馴染ませる)
                    SignInWithAppleButton(.signIn) { request in
                        let prepared = authViewModel.prepareAppleSignIn()
                        request.requestedScopes = prepared.requestedScopes
                        request.nonce = prepared.nonce
                    } onCompletion: { result in
                        Task { @MainActor in
                            await authViewModel.handleAppleSignIn(result: result)
                            if case .authenticated = authViewModel.authState {
                                onAdvance()
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .black : .black)
                    .frame(height: 50)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.clTextPrimary.opacity(colorScheme == .dark ? 0.3 : 0), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)

                    // Google Sign In (T5: OAuth web flow)
                    Button {
                        Task { @MainActor in
                            await authViewModel.handleGoogleSignIn()
                            if case .authenticated = authViewModel.authState {
                                onAdvance()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            GoogleLogo()
                                .frame(width: 18, height: 18)
                            Text("Googleでログイン")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .strokeBorder(Color.clTextPrimary.opacity(0.35), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    // GitHub Sign In (T5: OAuth web flow)
                    Button {
                        Task { @MainActor in
                            await authViewModel.handleGitHubSignIn()
                            if case .authenticated = authViewModel.authState {
                                onAdvance()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.clTextPrimary)
                            Text("GitHubでログイン")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .strokeBorder(Color.clTextPrimary.opacity(0.35), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    // Skip
                    Button {
                        HapticManager.light()
                        onSkip()
                    } label: {
                        Text("あとで")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.clTextPrimary.opacity(0.4))
                    }
                    .padding(.top, 4)
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
    static func iconColor(for name: String) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.20, 0.25, 0.45), (0.25, 0.15, 0.35), (0.15, 0.20, 0.32),
            (0.18, 0.28, 0.25), (0.28, 0.18, 0.22), (0.22, 0.22, 0.35),
        ]
        let index = abs(name.hashValue) % palette.count
        let (r, g, b) = palette[index]
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Google Logo (4色公式カラー)

private struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1
            let lineWidth: CGFloat = radius * 0.38

            let colors: [(Color, Angle, Angle)] = [
                (Color(red: 0.92, green: 0.26, blue: 0.21), .degrees(-45), .degrees(45)),    // red (top-right)
                (Color(red: 0.98, green: 0.74, blue: 0.02), .degrees(45), .degrees(135)),     // yellow (bottom-right)
                (Color(red: 0.22, green: 0.65, blue: 0.32), .degrees(135), .degrees(225)),    // green (bottom-left)
                (Color(red: 0.26, green: 0.52, blue: 0.96), .degrees(225), .degrees(315)),    // blue (top-left)
            ]

            for (color, start, end) in colors {
                var path = Path()
                path.addArc(center: center, radius: radius - lineWidth / 2,
                            startAngle: start, endAngle: end, clockwise: false)
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }

            // Right bar of "G"
            let barRect = CGRect(
                x: center.x,
                y: center.y - lineWidth / 2,
                width: radius,
                height: lineWidth
            )
            context.fill(Path(barRect), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }
}

#Preview {
    OnboardingAccountPromptStep(
        projectName: "つくろぐ",
        platform: "iOS",
        authViewModel: AuthViewModel(authService: NoOpAuthService()),
        onAdvance: {},
        onSkip: {}
    )
}
