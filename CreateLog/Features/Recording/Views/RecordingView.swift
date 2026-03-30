import SwiftUI

struct RecordingView: View {
    @Binding var tabBarOffset: CGFloat

    @State private var isTimerRunning = false
    @State private var activeProject: String?
    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var inputText = ""
    @State private var showManualInput = false
    @State private var showParsedPreview = false
    @FocusState private var isInputFocused: Bool

    private let recentProjects = [
        ("iOS開発", "chevron.left.forwardslash.chevron.right"),
        ("学習", "book.fill"),
        ("バグ修正", "ladybug.fill"),
    ]

    // Mock data — バックエンド接続時に置き換え
    private let mockTodayHours: Double = 4.25
    private let mockTotalHours: Double = 342.5
    private let mockWeekDiff: Double = 2.3 // 今週 - 先週

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // KPI summary
                kpiRow
                    .padding(.horizontal, 16)

                // Timer / Quick Start
                timerSection
                    .padding(.horizontal, 16)

                // Manual input
                manualInputSection
                    .padding(.horizontal, 16)

                Spacer(minLength: 100)
            }
            .padding(.top, 28)
        }
        .scrollIndicators(.hidden)
        .onDisappear {
            timerTask?.cancel()
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiItem(
                value: String(format: "%.1f", mockTodayHours),
                unit: "h",
                label: "今日"
            )

            kpiItem(
                value: String(format: "%.0f", mockTotalHours),
                unit: "h",
                label: "累計"
            )

            kpiItem(
                value: (mockWeekDiff >= 0 ? "+" : "") + String(format: "%.1f", mockWeekDiff),
                unit: "h",
                label: "前週比",
                valueColor: mockWeekDiff >= 0 ? Color.clSuccess : Color.clError
            )
        }
    }

    private func kpiItem(
        value: String,
        unit: String,
        label: String,
        valueColor: Color = Color.clTextPrimary
    ) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(valueColor)
                Text(unit)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextTertiary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 12) {
            if isTimerRunning {
                runningTimer
            } else {
                quickStartGrid
            }
        }
    }

    private var runningTimer: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text(formattedTime)
                    .font(.system(size: 48, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.clAccent)
                    .contentTransition(.numericText())

                if let project = activeProject {
                    let entry = LogEntry(title: "", categoryName: project, startHour: 0, endHour: 0)
                    HStack(spacing: 6) {
                        Image(systemName: entry.categoryIcon)
                            .font(.system(size: 12))
                        Text(project)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(entry.categoryColor)
                }

                Button {
                    stopTimer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                        Text("記録を停止")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.clError, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private var quickStartGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Text("記録を開始")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                Spacer()
            }

            ForEach(recentProjects, id: \.0) { name, icon in
                let entry = LogEntry(title: "", categoryName: name, startHour: 0, endHour: 0)
                Button {
                    startTimer(project: name)
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.categoryColor)
                            .frame(width: 4, height: 28)

                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(entry.categoryColor)
                            .frame(width: 20)

                        Text(name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)

                        Spacer()

                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(entry.categoryColor.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(entry.categoryColor.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(entry.categoryColor.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                HapticManager.light()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("新しいプロジェクト")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.clTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Timer Logic

    private var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer(project: String) {
        activeProject = project
        elapsedSeconds = 0
        isTimerRunning = true
        HapticManager.medium()

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isTimerRunning = false
        }
        HapticManager.success()
    }

    // MARK: - Manual Input

    private var manualInputSection: some View {
        VStack(spacing: 8) {
            if showManualInput {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.clAccent.opacity(0.7))

                    TextField("例: iOS開発 3時間", text: $inputText)
                        .font(.clBody)
                        .foregroundStyle(Color.clTextPrimary)
                        .focused($isInputFocused)
                        .onSubmit {
                            guard !inputText.isEmpty else { return }
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                showParsedPreview = true
                            }
                            HapticManager.light()
                        }

                    if !inputText.isEmpty {
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                showParsedPreview = true
                            }
                            isInputFocused = false
                            HapticManager.light()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.clAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            showManualInput = false
                            inputText = ""
                            showParsedPreview = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.clTextTertiary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clSurfaceLow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    isInputFocused ? Color.clAccent.opacity(0.4) : Color.clBorder,
                                    lineWidth: 1
                                )
                        )
                )
                .animation(.easeOut(duration: 0.2), value: isInputFocused)

                if showParsedPreview {
                    parsedPreview
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        showManualInput = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12))
                        Text("手動で記録を追加")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var parsedPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.clAccent)
                Text("解析結果")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.clAccent)
                Spacer()
            }

            let mock = LogEntry(title: "", categoryName: "iOS開発", startHour: 0, endHour: 0)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(mock.categoryColor)
                    .frame(width: 3, height: 24)
                Text("iOS開発")
                    .font(.clBody)
                    .foregroundStyle(Color.clTextPrimary)
                Spacer()
                Text("3h")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.clTextSecondary)
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    showParsedPreview = false
                    showManualInput = false
                    inputText = ""
                }
                HapticManager.success()
            } label: {
                Text("記録する")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.clAccent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassBackground(cornerRadius: 16)
    }
}
