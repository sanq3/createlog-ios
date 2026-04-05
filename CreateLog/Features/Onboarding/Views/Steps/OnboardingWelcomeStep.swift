import SwiftUI

/// Step 07: つくろぐへようこそ。
/// 保存したカード + 薄い空の週ビューを表示し、「ここから積み上げていく」のメッセージ。
/// 「はじめる」ボタンで本編に遷移 (isPresented = false)。
/// 静かな登場、急がせない。
struct OnboardingWelcomeStep: View {
    let projectName: String
    let durationMinutes: Int
    let categoryName: String
    let onFinish: () -> Void

    @State private var titleAppeared = false
    @State private var cardAppeared = false
    @State private var weekAppeared = false
    @State private var ctaAppeared = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                VStack(spacing: 8) {
                    Text("つくろぐへ")
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 10)
                    Text("ようこそ。")
                        .opacity(titleAppeared ? 1 : 0)
                        .offset(y: titleAppeared ? 0 : 10)
                        .blur(radius: titleAppeared ? 0 : 4)
                }
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .tracking(-0.5)

                Spacer().frame(height: 28)

                Text("これが、最初の 1 件。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                    .opacity(titleAppeared ? 0.8 : 0)

                Spacer().frame(height: 36)

                savedCard
                    .opacity(cardAppeared ? 1 : 0)
                    .scaleEffect(cardAppeared ? 1 : 0.95)
                    .blur(radius: cardAppeared ? 0 : 6)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                emptyWeekPreview
                    .opacity(weekAppeared ? 0.35 : 0)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 6) {
                    Text("ここから積み上げていく。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextSecondary)

                    Button {
                        HapticManager.medium()
                        onFinish()
                    } label: {
                        Text("はじめる")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.clBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule().fill(Color.clTextPrimary)
                            )
                            .padding(.horizontal, 32)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .opacity(ctaAppeared ? 1 : 0)
                .offset(y: ctaAppeared ? 0 : 20)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(0.2)) {
                titleAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(duration: 0.8, bounce: 0.2)) {
                    cardAppeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.9)) {
                    weekAppeared = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    ctaAppeared = true
                }
            }
        }
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(categoryName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.clTextTertiary)
                .tracking(1.5)
                .textCase(.uppercase)

            Text(projectName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .lineLimit(1)

            Text(DurationFormatter.format(minutes: durationMinutes))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    private var emptyWeekPreview: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.clTextPrimary.opacity(index == 0 ? 0.35 : 0.08))
                        .frame(width: 18, height: index == 0 ? 28 : 8)
                    Text(dayLabel(index))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayLabel(_ index: Int) -> String {
        ["今日", "明日", "水", "木", "金", "土", "日"][index]
    }
}

#Preview {
    OnboardingWelcomeStep(
        projectName: "つくろぐ iOS",
        durationMinutes: 90,
        categoryName: "開発",
        onFinish: {}
    )
}
