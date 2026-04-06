import SwiftUI

/// Step 02: アプリの実在する主要機能を 2 枚のカードで紹介。
/// 記録 (タイマー + タグ) とレポート (週間チャート + KPI) のみ。存在しない機能は表示しない。
struct OnboardingAppShowcaseStep: View {
    let onAdvance: () -> Void

    @State private var currentPage = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                TabView(selection: $currentPage) {
                    featureCard(
                        title: "作業を記録する",
                        subtitle: "タイマーや手入力で\n日々の開発時間を記録",
                        content: { recordingMockup }
                    ).tag(0)

                    featureCard(
                        title: "レポートで振り返る",
                        subtitle: "週間チャートとカテゴリ別集計で\n自分の作業パターンを把握",
                        content: { reportMockup }
                    ).tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.96)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(currentPage == i ? Color.clTextPrimary : Color.clTextTertiary.opacity(0.25))
                            .frame(width: currentPage == i ? 20 : 6, height: 6)
                            .animation(.spring(duration: 0.35, bounce: 0.2), value: currentPage)
                    }
                }
                .padding(.top, 12)

                Spacer()

                Button {
                    HapticManager.light()
                    onAdvance()
                } label: {
                    Text("続ける")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clBackground)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.clTextPrimary))
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Card Template

    private func featureCard<V: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> V
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .tracking(-0.5)

            Spacer().frame(height: 10)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.clTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer().frame(height: 32)

            content()
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Recording Mockup (実在)

    private var recordingMockup: some View {
        VStack(spacing: 20) {
            Text("1:30")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)

            HStack(spacing: 8) {
                ForEach(["開発", "デザイン", "学習"], id: \.self) { tag in
                    let selected = tag == "開発"
                    Text(tag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Color.clBackground : Color.clTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
                        )
                }
            }
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clSurfaceHigh.opacity(0.5))
        )
    }

    // MARK: - Report Mockup (実在)

    private var reportMockup: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 10) {
                let heights: [CGFloat] = [48, 36, 72, 24, 60, 84, 40]
                let days = ["月", "火", "水", "木", "金", "土", "日"]
                ForEach(Array(zip(days, heights)), id: \.0) { day, height in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day == "土" ? Color.clAccent : Color.clTextPrimary.opacity(0.15))
                            .frame(width: 22, height: height)

                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)

            HStack {
                Text("今週の合計")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                Spacer()
                Text("12h 45m")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clSurfaceHigh.opacity(0.5))
        )
    }
}

#Preview {
    OnboardingAppShowcaseStep(onAdvance: {})
}
