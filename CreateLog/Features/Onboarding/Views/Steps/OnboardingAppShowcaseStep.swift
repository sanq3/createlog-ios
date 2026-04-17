import SwiftUI

/// Step 02: Apple.com 風 3D カルーセル (button 主導)。
/// 6層 premium iPhone フレーム + 「記録する」ボタンで check flash → スライド → timeline 更新の 3 段演出。
struct OnboardingAppShowcaseStep: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phoneAppeared = false
    @State private var timerCount = 0
    @State private var selectedTag = "開発"
    @State private var showCheckFlash = false
    @State private var newRecordAppeared = false
    @State private var chartBarsGrown = false
    @State private var scrollPosition: Int? = 0
    @State private var kpiTodayMinutes: Int = 120
    @State private var phone2Tilting = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                Text(scrollPosition == 0 ? "作業を記録する" : "タイムラインに追加される")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .contentTransition(.interpolate)
                    .animation(.spring(duration: 0.4), value: scrollPosition)

                Spacer().frame(height: 4)

                Text(scrollPosition == 0
                     ? "タイマーや手入力で開発時間を記録"
                     : "いつでも見返せる作業の記録")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.6))
                    .contentTransition(.interpolate)
                    .animation(.spring(duration: 0.4), value: scrollPosition)

                Spacer().frame(height: 12)

                // ScrollView カルーセル
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        premiumPhone { recordingScreenView }
                            .id(0)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.8)
                                    .rotation3DEffect(
                                        .degrees(phase.isIdentity ? 0 : phase.value * -30),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.4
                                    )
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                            }

                        premiumPhone { timelineScreenView }
                            .id(1)
                            .rotation3DEffect(
                                .degrees(phone2Tilting ? 1.5 : -1.5),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.45
                            )
                            .scaleEffect(phone2Tilting ? 1.01 : 0.99)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.8)
                                    .rotation3DEffect(
                                        .degrees(phase.isIdentity ? 0 : phase.value * -30),
                                        axis: (x: 0, y: 1, z: 0),
                                        perspective: 0.4
                                    )
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                            }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 90)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollPosition)
                .frame(height: 440)
                .opacity(phoneAppeared ? 1 : 0)
                .offset(y: phoneAppeared ? 0 : 40)

                Spacer()

                OnboardingPrimaryCTA(
                    title: "続ける",
                    disabledStyle: .dimmed,
                    action: onAdvance
                )
                .opacity(phoneAppeared ? 1 : 0)
                .offset(y: phoneAppeared ? 0 : 20)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.12).delay(0.2)) {
                phoneAppeared = true
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            if newValue == 1 && !chartBarsGrown {
                withAnimation(.spring(duration: 1.0, bounce: 0.1)) {
                    chartBarsGrown = true
                }
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) {
                        phone2Tilting = true
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.8))
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0))
                timerCount += 1
            }
        }
        .task(id: scrollPosition) {
            guard scrollPosition == 1, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.0))
                if Task.isCancelled || scrollPosition != 1 { break }
                withAnimation(.spring(duration: 0.4)) {
                    kpiTodayMinutes += 1
                }
            }
        }
    }

    // MARK: - 6層 Premium Phone Frame

    private func premiumPhone<V: View>(@ViewBuilder content: () -> V) -> some View {
        let outerRadius: CGFloat = 44
        let innerRadius: CGFloat = 40
        let bezelPad: CGFloat = 4

        return ZStack {
            // Layer 1: Bevel (メタリック縁)
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.35), Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Layer 2: Body (筐体)
            RoundedRectangle(cornerRadius: outerRadius - 1, style: .continuous)
                .fill(Color(white: 0.06))
                .padding(1)

            // Layer 3: Screen content
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clBackground)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .padding(bezelPad)

            // Layer 4: Inset shadow (深度リング)
            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
                .blur(radius: 1.5)
                .padding(bezelPad)
                .allowsHitTesting(false)

            // Layer 5: Glass glint (スペキュラーハイライト)
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.1), location: 0),
                            .init(color: .white.opacity(0.1), location: 0.35),
                            .init(color: .clear, location: 0.351),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)

            // Layer 6: Ambient wash (環境光)
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)

            // Dynamic Island
            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 80, height: 24)
                    .overlay(
                        Capsule()
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.15), .black],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 16
                                )
                            )
                    )
                    .padding(.top, 12)
                Spacer()
            }
            .padding(bezelPad)
            .allowsHitTesting(false)
        }
        .frame(width: 210, height: 430)
    }

    // MARK: - Recording Screen

    private var recordingScreenView: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 46)
                Text("記録")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                Spacer().frame(height: 14)
                HStack(spacing: 0) {
                    miniKpi("30m", "今日")
                    miniKpi("12h", "累計")
                    miniKpi("15%", "先週比")
                }
                .padding(.horizontal, 10)
                Spacer().frame(height: 14)
                Text(timerText)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: timerCount)
                Spacer().frame(height: 12)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
                    ForEach(["開発", "デザイン", "学習", "設計"], id: \.self) { tag in
                        let on = selectedTag == tag
                        Button {
                            HapticManager.light()
                            withAnimation(.spring(duration: 0.25)) { selectedTag = tag }
                        } label: {
                            Text(LocalizedStringKey(tag))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(on ? Color.clBackground : Color.clTextPrimary.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(on ? Color.clTextPrimary : Color.clSurfaceHigh))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                Spacer().frame(height: 10)
                ZStack {
                    Button {
                        HapticManager.light()
                        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                            showCheckFlash = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showCheckFlash = false
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.spring(duration: 0.55, bounce: 0.12)) {
                                scrollPosition = 1
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                            HapticManager.success()
                            newRecordAppeared = true
                        }
                    } label: {
                        Text("記録する")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.clBackground)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.clTextPrimary))
                    }
                    .buttonStyle(.plain)

                    if showCheckFlash {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.clAccent)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                            .zIndex(10)
                            .allowsHitTesting(false)
                    }
                }
                Spacer().frame(height: 12)
                VStack(spacing: 6) {
                    timelineRow("つくろぐ", "1h 30m", Color.clCat01)
                    timelineRow("ポートフォリオ", "45m", Color.clCat02)
                    timelineRow("Swift学習", "2h", Color.clCat03)
                }
                .padding(.horizontal, 12)
                Spacer()
            }
        }
    }

    private var timerText: String {
        String(format: "%d:%02d", timerCount / 60, timerCount % 60)
    }

    private var kpiTodayText: String {
        String(format: "%dh %02dm", kpiTodayMinutes / 60, kpiTodayMinutes % 60)
    }

    // MARK: - Timeline Screen

    private var timelineScreenView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 46)
            Text("記録")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
            Spacer().frame(height: 12)

            // KPI 行
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text(kpiTodayText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.clTextPrimary)
                        .contentTransition(.numericText(countsDown: false))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("今日")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                miniKpi("12h", "今週")
                miniKpi("48h", "今月")
            }
            .padding(.horizontal, 10)
            Spacer().frame(height: 14)

            // 週間バーチャート
            HStack(alignment: .bottom, spacing: 4) {
                let heights: [CGFloat] = [32, 24, 48, 16, 40, 56, 28]
                let days: [LocalizedStringKey] = ["月", "火", "水", "木", "金", "土", "日"]
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(index == 5 ? Color.clAccent : Color.clTextPrimary.opacity(0.15))
                            .frame(width: 12, height: chartBarsGrown ? heights[index] : 4)
                        Text(day)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 76)
            .padding(.horizontal, 14)
            Spacer().frame(height: 14)

            // タイムラインセクション
            HStack {
                Text("今日の記録")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 12)
            Spacer().frame(height: 6)

            VStack(spacing: 6) {
                if newRecordAppeared {
                    timelineRow(LocalizedStringKey(selectedTag), "30m", Color.clCat04, highlighted: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .identity
                        ))
                }
                timelineRow("つくろぐ", "1h 30m", Color.clCat01)
                timelineRow("ポートフォリオ", "45m", Color.clCat02)
                timelineRow("Swift学習", "2h", Color.clCat03)
            }
            .padding(.horizontal, 12)
            .animation(.spring(duration: 0.65, bounce: 0.25), value: newRecordAppeared)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func timelineRow(_ name: LocalizedStringKey, _ time: String, _ color: Color, highlighted: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: highlighted ? 4 : 3, height: 12)
            Text(name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.clTextPrimary.opacity(highlighted ? 0.9 : 0.7))
            Spacer()
            Text(time)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clTextPrimary.opacity(0.5))
        }
        .padding(.horizontal, highlighted ? 4 : 0)
        .padding(.vertical, highlighted ? 3 : 0)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.08))
            }
        }
    }

    private func miniKpi(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(Color.clTextPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingAppShowcaseStep(onAdvance: {})
}
