import SwiftUI

struct RecordingView: View {
    @Binding var tabBarOffset: CGFloat

    @State private var isTimerRunning = false
    @State private var activeProject: String?
    @State private var activeCategory: String?
    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var inputText = ""
    @State private var expandedCategory: String?
    @FocusState private var isInputFocused: Bool

    // 標準カテゴリ → プロジェクト (2層構造)
    private let categoryProjects: [(category: String, projects: [String])] = [
        ("開発", ["CreateLog", "FocusFlow", "Tempo"]),
        ("デザイン", ["CreateLog UI", "ポートフォリオ"]),
        ("学習", ["Swift Concurrency", "React入門"]),
        ("ミーティング", ["社内定例", "1on1"]),
        ("ライティング", ["技術ブログ", "ドキュメント"]),
        ("マーケティング", ["SNS運用", "ASO"]),
        ("事務", ["経理", "確定申告"]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Running timer bar
                if isTimerRunning {
                    runningTimerBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Quick add
                quickAddInput
                    .padding(.horizontal, 16)
                    .padding(.top, isTimerRunning ? 0 : 12)
                    .padding(.bottom, 16)

                // Category → Project picker
                if !isTimerRunning {
                    categorySection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                // Divider
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // History
                historySection
                    .padding(.top, 14)
                    .padding(.horizontal, 16)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .onDisappear {
            timerTask?.cancel()
        }
    }

    // MARK: - Running Timer Bar

    private var runningTimerBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.clError)
                .frame(width: 8, height: 8)
                .scaleEffect(isTimerRunning ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: isTimerRunning)

            if let cat = activeCategory {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LogEntry.color(for: cat))
                    .frame(width: 3, height: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                if let proj = activeProject {
                    Text(proj)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                }
                if let cat = activeCategory {
                    Text(cat)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
            }

            Spacer()

            Text(formattedTime)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.clTextPrimary)
                .contentTransition(.numericText())

            Button {
                stopTimer()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.clError, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 14)
    }

    // MARK: - Quick Add Input

    private var quickAddInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.clAccent)

            TextField("開発 CreateLog 3時間", text: $inputText)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextPrimary)
                .focused($isInputFocused)
                .onSubmit { addManualRecord() }

            if !inputText.isEmpty {
                Button {
                    addManualRecord()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.clAccent)
                }
                .buttonStyle(.plain)
            }
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
    }

    // MARK: - Category → Project Picker

    private var categorySection: some View {
        VStack(spacing: 6) {
            ForEach(categoryProjects, id: \.category) { item in
                let isExpanded = expandedCategory == item.category
                let color = LogEntry.color(for: item.category)

                VStack(spacing: 0) {
                    // Category row
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            expandedCategory = isExpanded ? nil : item.category
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 4, height: 22)

                            Text(item.category)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.clTextPrimary)

                            Spacer()

                            Text("\(item.projects.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.clTextTertiary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.clTextTertiary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    // Projects (expanded)
                    if isExpanded {
                        VStack(spacing: 0) {
                            ForEach(item.projects, id: \.self) { project in
                                Button {
                                    startTimer(category: item.category, project: project)
                                } label: {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(color.opacity(0.3))
                                            .frame(width: 6, height: 6)

                                        Text(project)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.clTextPrimary)

                                        Spacer()

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(color.opacity(0.5))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }

                            // Add new project
                            Button {
                                HapticManager.light()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("追加")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Color.clTextTertiary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isExpanded ? color.opacity(0.04) : .clear)
                )
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の記録")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.clTextTertiary)

            ForEach(MockData.todayLogs) { log in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(log.categoryColor)
                        .frame(width: 3, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text(log.categoryName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(log.categoryColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(log.durationString)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.clTextPrimary)
                        Text(log.timeRangeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .padding(.vertical, 8)

                if log.id != MockData.todayLogs.last?.id {
                    Divider()
                }
            }
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

    private func startTimer(category: String, project: String) {
        activeCategory = category
        activeProject = project
        elapsedSeconds = 0
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            isTimerRunning = true
            expandedCategory = nil
        }
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
        activeProject = nil
        activeCategory = nil
        HapticManager.success()
    }

    private func addManualRecord() {
        guard !inputText.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        HapticManager.success()
    }
}
