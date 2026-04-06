import SwiftUI
import Charts

struct ShareReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: SharePeriod = .week
    @State private var renderedImage: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period selector
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(SharePeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Card preview
                ScrollView {
                    shareCard
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                Spacer()

                // Share button
                ShareLink(
                    item: renderedImage ?? Image(systemName: "square"),
                    preview: SharePreview(
                        "CreateLog レポート",
                        image: renderedImage ?? Image(systemName: "square")
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("シェアする")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clAccent, in: .capsule)
                }
                .buttonStyle(.bounce)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.clBackground)
            .navigationTitle("レポートをシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            }
            .onAppear { renderImage() }
            .onChange(of: selectedPeriod) { _, _ in renderImage() }
        }
    }

    // MARK: - Share Card

    @ViewBuilder
    private var shareCard: some View {
        let cardContent = ShareCardContent(period: selectedPeriod)

        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardContent.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(cardContent.dateRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                // App logo watermark
                VStack(spacing: 2) {
                    Text("つくろぐ")
                        .font(.system(size: 11, weight: .heavy))
                    Text("CreateLog")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.clAccent, Color.clAccent.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Stats
            HStack(spacing: 0) {
                statColumn(value: cardContent.totalTime, label: "合計")
                statDivider
                statColumn(value: cardContent.dailyAvg, label: "日平均")
                statDivider
                statColumn(value: "\(cardContent.activeDays)日", label: "稼働日")
            }
            .padding(.vertical, 20)
            .background(Color(.systemBackground))

            // Category breakdown
            VStack(spacing: 12) {
                ForEach(cardContent.categories, id: \.name) { cat in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(cat.color)
                            .frame(width: 8, height: 8)

                        Text(cat.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.label))

                        Spacer()

                        // Progress bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                Capsule()
                                    .fill(cat.color)
                                    .frame(width: proxy.size.width * cat.ratio)
                            }
                        }
                        .frame(width: 80, height: 6)

                        Text(DurationFormatter.formatHM(hours: cat.hours))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))

            // Footer
            HStack {
                Text("@\("username" /* TODO: from auth */)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
                Text("createlog.app")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Render

    private func renderImage() {
        let renderer = ImageRenderer(content: shareCard.frame(width: 340))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - Models

enum SharePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case total

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "今週"
        case .month: "今月"
        case .total: "累計"
        }
    }
}

private struct ShareCardContent {
    let title: String
    let dateRange: String
    let totalTime: String
    let dailyAvg: String
    let activeDays: Int
    let categories: [CategoryStat]

    struct CategoryStat {
        let name: String
        let hours: Double
        let ratio: CGFloat
        let color: Color
    }

    init(period: SharePeriod) {
        switch period {
        case .week:
            title = "週間レポート"
            dateRange = "2026年3月20日 - 3月26日"
            totalTime = DurationFormatter.formatHM(hours: 28.5)
            dailyAvg = DurationFormatter.formatHM(hours: 4.1)
            activeDays = 6
        case .month:
            title = "月間レポート"
            dateRange = "2026年3月"
            totalTime = DurationFormatter.formatHM(hours: 58.3)
            dailyAvg = DurationFormatter.formatHM(hours: 3.2)
            activeDays = 18
        case .total:
            title = "累計レポート"
            dateRange = "2026年1月 - 3月"
            totalTime = DurationFormatter.formatHM(hours: 186.0)
            dailyAvg = DurationFormatter.formatHM(hours: 3.5)
            activeDays = 52
        }

        let maxHours = 24.5
        categories = [
            .init(name: "iOS開発", hours: 24.5, ratio: 24.5 / maxHours, color: LogEntry.color(for: "iOS開発")),
            .init(name: "学習", hours: 12.0, ratio: 12.0 / maxHours, color: LogEntry.color(for: "学習")),
            .init(name: "バグ修正", hours: 8.5, ratio: 8.5 / maxHours, color: LogEntry.color(for: "バグ修正")),
            .init(name: "Web開発", hours: 7.8, ratio: 7.8 / maxHours, color: LogEntry.color(for: "Web開発")),
            .init(name: "デザイン", hours: 5.5, ratio: 5.5 / maxHours, color: LogEntry.color(for: "デザイン")),
        ]
    }
}
