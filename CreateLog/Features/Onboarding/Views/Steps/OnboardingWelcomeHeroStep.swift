import SwiftUI

/// Step 01: ようこそ、CreateLog へ。
/// "CreateLog" をレターバイレター stagger で登場させ、着地後に shimmer を走らせる。
struct OnboardingWelcomeHeroStep: View {
    let onAdvance: () -> Void

    private static let logo: [String] = ["C","r","e","a","t","e","L","o","g"]

    @State private var greetingVisible = false
    @State private var lettersVisible = false
    @State private var shimmerOffset: CGFloat = -0.5
    @State private var breathe = false
    @State private var hintVisible = false

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

                // "ようこそ、"
                Text("ようこそ、")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : -8)

                Spacer().frame(height: 18)

                // "CreateLog" letter-by-letter stagger
                ZStack {
                    // Shimmer layer (text-shaped mask)
                    logoText
                        .foregroundStyle(.clear)
                        .overlay {
                            LinearGradient(
                                colors: [.clear, Color.clTextPrimary.opacity(0.25), .clear],
                                startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
                            )
                            .mask(logoText)
                        }

                    // Main letters
                    HStack(spacing: -1.5) {
                        ForEach(Array(Self.logo.enumerated()), id: \.offset) { index, char in
                            Text(char)
                                .opacity(lettersVisible ? 1 : 0)
                                .offset(y: lettersVisible ? 0 : 28)
                                .blur(radius: lettersVisible ? 0 : 8)
                                .scaleEffect(lettersVisible ? 1 : 0.7)
                                .animation(
                                    .spring(duration: 0.65, bounce: 0.2)
                                        .delay(0.35 + Double(index) * 0.055),
                                    value: lettersVisible
                                )
                        }
                    }
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(Color.clTextPrimary)
                }
                .scaleEffect(breathe ? 1.006 : 1.0)

                Spacer().frame(height: 12)

                // "へ。"
                Text("へ。")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : 6)

                Spacer()

                Text("タップして続ける")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                    .opacity(hintVisible ? 0.6 : 0)
                    .padding(.bottom, 48)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            // 1. Letters stagger in
            lettersVisible = true

            // 2. "ようこそ、" + "へ。" fade in after letters land
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(1.1)) {
                greetingVisible = true
            }

            // 3. Shimmer sweep after all letters settled
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    shimmerOffset = 1.5
                }
            }

            // 4. Breathing
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(2.2)) {
                breathe = true
            }

            // 5. Tap hint
            withAnimation(.easeOut(duration: 0.6).delay(2.5)) {
                hintVisible = true
            }
        }
    }

    /// Shared text style for shimmer mask alignment
    private var logoText: some View {
        Text("CreateLog")
            .font(.system(size: 52, weight: .black))
    }
}

#Preview {
    OnboardingWelcomeHeroStep(onAdvance: {})
}
