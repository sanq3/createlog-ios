import SwiftUI

/// Step 04: プラットフォーム選択 (複数選択)。
/// 同じプロダクトが iOS + Android 等の複数プラットフォーム対応を想定。
struct OnboardingPlatformStep: View {
    @Binding var selectedPlatforms: Set<String>
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var chipsAppeared = false

    private static let platforms = ["iOS", "Android", "Web", "Desktop", "その他"]

    private var canAdvance: Bool { !selectedPlatforms.isEmpty }

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                Text("現在製作中、制作予定の\nプラットフォームは？")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 8)

                Text("複数選択できます")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 36)

                platformGrid
                    .padding(.horizontal, 32)

                Spacer()

                OnboardingPrimaryCTA(
                    title: "続ける",
                    isEnabled: canAdvance,
                    disabledStyle: .dimmed,
                    action: onAdvance
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    chipsAppeared = true
                }
            }
        }
    }

    private var platformGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(Self.platforms.enumerated()), id: \.offset) { index, platform in
                chip(platform, index: index)
            }
        }
    }

    private func chip(_ platform: String, index: Int) -> some View {
        let selected = selectedPlatforms.contains(platform)
        return Button {
            HapticManager.selection()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if selected {
                    selectedPlatforms.remove(platform)
                } else {
                    selectedPlatforms.insert(platform)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(platform)
                    .font(.system(size: 16, weight: .semibold))
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(selected ? Color.clBackground : Color.clTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
                .background(
                    Capsule().fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selected ? Color.clear : Color.clTextPrimary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(chipsAppeared ? 1 : 0)
        .offset(y: chipsAppeared ? 0 : 14)
        .animation(
            .spring(duration: 0.6, bounce: 0.2).delay(Double(index) * 0.04),
            value: chipsAppeared
        )
    }
}

#Preview {
    OnboardingPlatformStep(selectedPlatforms: .constant(["iOS"]), onAdvance: {})
}
