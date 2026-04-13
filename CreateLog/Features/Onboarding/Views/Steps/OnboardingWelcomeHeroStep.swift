import SwiftUI

/// Step 01: CreateLog ブランド。
/// letter entrance は速め → 着地後の wave / shimmer / breathing はスローで余韻。
struct OnboardingWelcomeHeroStep: View {
    let onAdvance: () -> Void
    let onLogin: () -> Void

    private static let logo: [String] = ["C","r","e","a","t","e","L","o","g"]

    @State private var lettersVisible = false
    @State private var waving = false
    @State private var tagline1Visible = false
    @State private var tagline2Visible = false
    @State private var shimmerOffset: CGFloat = -0.5
    @State private var breathe = false
    @State private var hintVisible = false
    @State private var hintPulse = false

    var body: some View {
        ZStack {
            Color.clBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard hintVisible else { return }
                    HapticManager.light()
                    onAdvance()
                }

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    logoMask
                        .foregroundStyle(.clear)
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                            )
                            .mask(logoMask)
                        }

                    HStack(spacing: -1.5) {
                        ForEach(Array(Self.logo.enumerated()), id: \.offset) { index, char in
                            Text(char)
                                // Entrance: 速め (元速度)
                                .opacity(lettersVisible ? 1 : 0)
                                .offset(y: lettersVisible ? 0 : 28)
                                .blur(radius: lettersVisible ? 0 : 8)
                                .scaleEffect(lettersVisible ? 1 : 0.7)
                                .animation(
                                    .spring(duration: 0.65, bounce: 0.2)
                                        .delay(0.35 + Double(index) * 0.055),
                                    value: lettersVisible
                                )
                                // Wave: スロー (ゆったり)
                                .offset(y: waving ? -3 : 0)
                                .animation(
                                    .easeInOut(duration: 1.2)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.12),
                                    value: waving
                                )
                        }
                    }
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(Color.clTextPrimary)
                }
                // Breathing: スロー
                .scaleEffect(breathe ? 1.012 : 1.0)

                Spacer().frame(height: 20)

                Text("エンジニアのためのアプリ")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(tagline1Visible ? 1 : 0)
                    .offset(y: tagline1Visible ? 0 : 8)

                Spacer().frame(height: 8)

                Text("自分だけの作業記録。新感覚のポートフォリオ")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.45))
                    .opacity(tagline2Visible ? 1 : 0)
                    .offset(y: tagline2Visible ? 0 : 6)

                Spacer()

                Text("タップして続ける")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(hintVisible ? (hintPulse ? 0.9 : 0.4) : 0)
                    .padding(.bottom, 64)
            }
            .allowsHitTesting(false)

            // ログインリンク (既存ユーザー向け、画面最下部)
            VStack {
                Spacer()
                Button {
                    HapticManager.light()
                    onLogin()
                } label: {
                    HStack(spacing: 4) {
                        Text("すでにアカウントをお持ちの方")
                            .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                        Text("ログイン")
                            .foregroundStyle(Color.clTextPrimary.opacity(0.85))
                            .underline()
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .opacity(hintVisible ? 1 : 0)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            lettersVisible = true

            withAnimation(.spring(duration: 0.7, bounce: 0.1).delay(1.4)) {
                tagline1Visible = true
            }
            withAnimation(.spring(duration: 0.7, bounce: 0.1).delay(1.8)) {
                tagline2Visible = true
            }
            // Wave: スロー開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                waving = true
            }
            // Breathing: スロー (5秒周期)
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true).delay(2.0)) {
                breathe = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(2.4)) {
                hintVisible = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(2.6)) {
                hintPulse = true
            }
        }
        .task {
            // Shimmer: スロー周期 (5秒間隔)
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 1.0)) { shimmerOffset = 1.5 }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5.0))
                shimmerOffset = -0.5
                withAnimation(.easeInOut(duration: 1.0)) { shimmerOffset = 1.5 }
            }
        }
    }

    private var logoMask: some View {
        Text("CreateLog")
            .font(.system(size: 52, weight: .black))
    }
}

#Preview {
    OnboardingWelcomeHeroStep(onAdvance: {}, onLogin: {})
}
