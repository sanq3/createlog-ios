import SwiftUI
import SwiftData

struct RecordingView: View {
    @Binding var tabBarOffset: CGFloat
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SDTimeEntry.startDate, order: .reverse) private var allEntries: [SDTimeEntry]
    @Query(sort: \SDProject.createdAt) private var myTags: [SDProject]

    @State private var showCreateTag = false
    @State private var showTimeInput = false
    @State private var selectedTag: SDProject?
    @State private var timeInputText = ""
    @FocusState private var isTimeFocused: Bool

    // Tag creation wizard
    @State private var wizardStep = 0
    @State private var selectedGenre = ""
    @State private var selectedActivity = ""
    @State private var projectName = ""
    @FocusState private var isProjectNameFocused: Bool

    private let genres: [(name: String, activities: [String])] = [
        ("プログラミング", ["iOS開発", "Android開発", "Web開発", "バックエンド", "インフラ", "バグ修正"]),
        ("デザイン", ["UIデザイン", "UXデザイン", "グラフィック", "ロゴ制作"]),
        ("学習", ["プログラミング学習", "語学", "読書", "資格勉強"]),
        ("クリエイティブ", ["動画制作", "音楽制作", "ライティング", "ブログ"]),
        ("ビジネス", ["マーケティング", "営業", "企画", "事務", "経理"]),
        ("コミュニケーション", ["ミーティング", "1on1", "レビュー", "メール対応"]),
    ]

    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // My tags
                    tagsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    Rectangle()
                        .fill(Color.clBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    // Recent records
                    historySection
                        .padding(.top, 14)
                        .padding(.horizontal, 16)

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            // Time input overlay
            if showTimeInput, let tag = selectedTag {
                timeInputOverlay(tag: tag)
            }

            // Tag creation wizard overlay
            if showCreateTag {
                tagCreationWizard
            }
        }
        .onDisappear {
            showCreateTag = false
            showTimeInput = false
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(spacing: 8) {
            if myTags.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Text("記録する項目を作ろう")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                    Text("よくやる作業をタグとして登録すると\nタップ+時間入力だけで記録できます")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
            } else {
                // Tag list
                ForEach(myTags) { tag in
                    Button {
                        selectedTag = tag
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            showTimeInput = true
                        }
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForTag(tag))
                                .frame(width: 4, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.clTextPrimary)
                                if let cat = tag.category {
                                    Text(cat.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.clTextTertiary)
                                }
                            }

                            Spacer()

                            // Last recorded time
                            if let last = lastEntry(for: tag) {
                                Text(formatDuration(last.durationMinutes))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(colorForTag(tag).opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorForTag(tag).opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(colorForTag(tag).opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Add tag button
            Button {
                resetWizard()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    showCreateTag = true
                }
                HapticManager.light()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("タグを追加")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.clTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Time Input Overlay

    private func timeInputOverlay(tag: SDProject) -> some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showTimeInput = false
                    timeInputText = ""
                }
            }
            .overlay {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForTag(tag))
                            .frame(width: 4, height: 24)
                        Text(tag.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        TextField("3時間", text: $timeInputText)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                            .focused($isTimeFocused)
                            .onSubmit { saveTimeEntry(tag: tag) }
                            .keyboardType(.default)

                        Button {
                            saveTimeEntry(tag: tag)
                        } label: {
                            Text("記録")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.clAccent, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(Color.clBackground, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 32)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTimeFocused = true
                    }
                }
            }
    }

    // MARK: - Tag Creation Wizard

    private var tagCreationWizard: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                    showCreateTag = false
                }
            }
            .overlay {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        if wizardStep > 0 {
                            Button {
                                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                                    wizardStep -= 1
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text(wizardTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Spacer()
                        Button {
                            withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                showCreateTag = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.clTextTertiary)
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                    Rectangle()
                        .fill(Color.clBorder)
                        .frame(height: 1)

                    // Steps
                    ScrollView {
                        VStack(spacing: 6) {
                            switch wizardStep {
                            case 0: genreStep
                            case 1: activityStep
                            case 2: projectNameStep
                            default: EmptyView()
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 300)
                }
                .background(Color.clBackground, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
            }
    }

    private var wizardTitle: String {
        switch wizardStep {
        case 0: return "ジャンルは？"
        case 1: return "何をする？"
        case 2: return "プロジェクト名（任意）"
        default: return ""
        }
    }

    private var genreStep: some View {
        ForEach(genres, id: \.name) { genre in
            Button {
                selectedGenre = genre.name
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    wizardStep = 1
                }
                HapticManager.light()
            } label: {
                HStack {
                    Text(genre.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clSurfaceLow)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var activityStep: some View {
        let activities = genres.first(where: { $0.name == selectedGenre })?.activities ?? []
        return ForEach(activities, id: \.self) { activity in
            Button {
                selectedActivity = activity
                withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                    wizardStep = 2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isProjectNameFocused = true
                }
                HapticManager.light()
            } label: {
                HStack {
                    Text(activity)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clSurfaceLow)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var projectNameStep: some View {
        VStack(spacing: 16) {
            Text("\(selectedActivity)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.clAccent)

            TextField("例: CreateLog, 個人アプリ名", text: $projectName)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextPrimary)
                .focused($isProjectNameFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clSurfaceLow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                )

            HStack(spacing: 12) {
                // Skip (no project name)
                Button {
                    saveTag(withProjectName: nil)
                } label: {
                    Text("スキップ")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Save with project name
                Button {
                    saveTag(withProjectName: projectName.isEmpty ? nil : projectName)
                } label: {
                    Text("作成")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の記録")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.clTextTertiary)

            if allEntries.isEmpty {
                Text("まだ記録がありません")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(allEntries.prefix(15)) { entry in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LogEntry.color(for: entry.categoryName))
                            .frame(width: 3, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.projectName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.clTextPrimary)
                            Text(entry.categoryName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(LogEntry.color(for: entry.categoryName))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatDuration(entry.durationMinutes))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.clTextPrimary)
                            Text(formatTime(entry.startDate))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.clTextTertiary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Logic

    private func saveTag(withProjectName name: String?) {
        let tagName: String
        if let name, !name.isEmpty {
            tagName = "\(selectedActivity) / \(name)"
        } else {
            tagName = selectedActivity
        }

        // Find or create category
        let categoryName = detectCategory(selectedGenre, activity: selectedActivity)
        let descriptor = FetchDescriptor<SDCategory>(predicate: #Predicate { cat in
            cat.name == categoryName
        })
        let category = (try? modelContext.fetch(descriptor))?.first

        let tag = SDProject(name: tagName, category: category)
        modelContext.insert(tag)

        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            showCreateTag = false
        }
        HapticManager.success()
    }

    private func saveTimeEntry(tag: SDProject) {
        let minutes = parseDuration(from: timeInputText)
        guard minutes > 0 else { return }

        let entry = SDTimeEntry(
            startDate: Date().addingTimeInterval(-Double(minutes * 60)),
            endDate: Date(),
            durationMinutes: minutes,
            projectName: tag.name,
            categoryName: tag.category?.name ?? "その他"
        )
        modelContext.insert(entry)

        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            showTimeInput = false
            timeInputText = ""
        }
        HapticManager.success()
    }

    private func resetWizard() {
        wizardStep = 0
        selectedGenre = ""
        selectedActivity = ""
        projectName = ""
    }

    private func detectCategory(_ genre: String, activity: String) -> String {
        switch genre {
        case "プログラミング": return "開発"
        case "デザイン": return "デザイン"
        case "学習": return "学習"
        case "クリエイティブ": return "ライティング"
        case "ビジネス": return "マーケティング"
        case "コミュニケーション": return "ミーティング"
        default: return "その他"
        }
    }

    private func colorForTag(_ tag: SDProject) -> Color {
        if let cat = tag.category {
            return Color(cat.colorName)
        }
        return Color("clCat07")
    }

    private func lastEntry(for tag: SDProject) -> SDTimeEntry? {
        allEntries.first(where: { $0.projectName == tag.name })
    }

    private func parseDuration(from text: String) -> Int {
        var total = 0
        if let match = text.range(of: "(\\d+)時間", options: .regularExpression) {
            total += (Int(text[match].replacingOccurrences(of: "時間", with: "")) ?? 0) * 60
        }
        if let match = text.range(of: "(\\d+)h", options: .regularExpression) {
            total += (Int(text[match].replacingOccurrences(of: "h", with: "")) ?? 0) * 60
        }
        if let match = text.range(of: "(\\d+)分", options: .regularExpression) {
            total += Int(text[match].replacingOccurrences(of: "分", with: "")) ?? 0
        }
        if let match = text.range(of: "(\\d+)m", options: .regularExpression) {
            total += Int(text[match].replacingOccurrences(of: "m", with: "")) ?? 0
        }
        // Just a number → treat as hours
        if total == 0, let num = Int(text.trimmingCharacters(in: .whitespaces)) {
            total = num * 60
        }
        return total
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
