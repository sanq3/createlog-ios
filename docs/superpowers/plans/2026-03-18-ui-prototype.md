# UI/UXプロトタイプ実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** シミュレータで触れるUI/UXプロトタイプを作る。機能は動かなくていい。見た目と触り心地の判断ができる状態にする。

**Architecture:** SwiftUI + MVVM。Supabase接続なし、全てダミーデータ。デザインシステムを先に作り、各画面で共通コンポーネントを使い回す。iOS 18+対応、iOS 26ではLiquid Glass拡張。

**Tech Stack:** Swift, SwiftUI, Swift Charts, SF Symbols

---

## ファイル構成

```
CreateLog/
  CreateLogApp.swift                    -- エントリポイント、タブ構成

  DesignSystem/
    Colors.swift                        -- カラートークン（ダーク/ライト）
    Typography.swift                    -- フォントスタイル定義
    GlassModifier.swift                 -- グラスモーフィズム（iOS 18互換 + iOS 26 Liquid Glass）
    HapticManager.swift                 -- ハプティクスフィードバック
    Components/
      GlassCard.swift                   -- ガラス風カードコンポーネント
      SkeletonView.swift                -- スケルトンローディング
      StatBadge.swift                   -- 統計バッジ（数字 + ラベル）
      AvatarView.swift                  -- ユーザーアバター + ステータスドット
      PostCardView.swift                -- 投稿カード（フィード用）
      ActionButton.swift                -- リアクションボタン（いいね等）
      SegmentedControl.swift            -- カスタムセグメントコントロール
      FloatingActionButton.swift        -- フローティング投稿ボタン
      WeeklyChart.swift                 -- 週間棒グラフ（Swift Charts）
      CategoryBreakdown.swift           -- カテゴリ別プログレスバー
      StreakCard.swift                   -- 連続記録カード
      ShareReportButton.swift           -- レポートシェアボタン

  Models/
    MockData.swift                      -- 全画面のダミーデータ

  Features/
    Home/
      HomeView.swift                    -- フィード画面
    Discover/
      DiscoverView.swift                -- 検索・発見画面
    Recording/
      RecordingTabView.swift            -- 記録タブ（セグメント切替）
      RecordingView.swift               -- 記録画面（タイマー + 今日の記録）
      ReportView.swift                  -- レポート画面（統計 + グラフ）
      CalendarView.swift                -- カレンダー画面（ヒートマップ）
    Notifications/
      NotificationsView.swift           -- 通知一覧
    Profile/
      ProfileView.swift                 -- プロフィール・ポートフォリオ
```

---

### Task 1: Xcodeプロジェクト作成

**Files:**
- Create: Xcode project `CreateLog` (iOS App, SwiftUI, Swift)

- [ ] **Step 1: Xcodeプロジェクトを作成**

ターミナルで以下を実行（Xcode CLIでプロジェクト生成はできないので手順を記載）:

```bash
cd /Users/個人開発/createlog-ios/createlog-ios
mkdir -p CreateLog
```

Xcodeを開き、File > New > Project > iOS > App を選択:
- Product Name: `CreateLog`
- Team: 自分のApple Developer Team
- Organization Identifier: 既存のBundle IDに合わせる
- Interface: SwiftUI
- Language: Swift
- Minimum Deployments: iOS 18.0
- 保存先: `/Users/個人開発/createlog-ios/createlog-ios/`

- [ ] **Step 2: ディレクトリ構成を作成**

```bash
cd /Users/個人開発/createlog-ios/createlog-ios/CreateLog
mkdir -p DesignSystem/Components
mkdir -p Models
mkdir -p Features/Home
mkdir -p Features/Discover
mkdir -p Features/Recording
mkdir -p Features/Notifications
mkdir -p Features/Profile
```

- [ ] **Step 3: ビルドして確認**

Run: Cmd+R in Xcode (iPhone 16 Pro Simulator)
Expected: 空のアプリが起動する

- [ ] **Step 4: コミット**

```bash
git add CreateLog/
git commit -m "feat: initialize Xcode project with directory structure"
```

---

### Task 2: デザインシステム — カラー & タイポグラフィ

**Files:**
- Create: `CreateLog/DesignSystem/Colors.swift`
- Create: `CreateLog/DesignSystem/Typography.swift`

- [ ] **Step 1: Colors.swift を作成**

```swift
import SwiftUI

extension Color {
    // MARK: - Background
    static let clBackground = Color("clBackground")
    static let clSurfaceLow = Color("clSurfaceLow")
    static let clSurfaceHigh = Color("clSurfaceHigh")

    // MARK: - Text
    static let clTextPrimary = Color("clTextPrimary")
    static let clTextSecondary = Color("clTextSecondary")
    static let clTextTertiary = Color("clTextTertiary")

    // MARK: - Accent
    static let clAccent = Color("clAccent")

    // MARK: - Semantic
    static let clSuccess = Color("clSuccess")
    static let clError = Color("clError")
    static let clRecording = Color("clRecording")

    // MARK: - Border
    static let clBorder = Color("clBorder")
}
```

Assets.xcassetsに以下のColor Setを追加（Any/Dark）:

| Name | Light | Dark |
|---|---|---|
| clBackground | #F8F8FA | #0E0E10 |
| clSurfaceLow | #00000008 | #C8C8DC08 |
| clSurfaceHigh | #0000000A | #C8C8DC0F |
| clTextPrimary | #1A1A1E | #E0E0EC |
| clTextSecondary | #1A1A1E73 | #C8C8DC73 |
| clTextTertiary | #1A1A1E40 | #C8C8DC40 |
| clAccent | #4A4A60 | #D0D0E0 |
| clSuccess | #4ADE80 | #4ADE80 |
| clError | #F87171 | #F87171 |
| clRecording | #60A5FA | #60A5FA |
| clBorder | #0000000F | #C8C8DC0F |

- [ ] **Step 2: Typography.swift を作成**

```swift
import SwiftUI

extension Font {
    // MARK: - Display
    static let clLargeTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let clTitle = Font.system(size: 20, weight: .bold, design: .default)

    // MARK: - Heading
    static let clHeadline = Font.system(size: 14, weight: .semibold, design: .default)

    // MARK: - Body
    static let clBody = Font.system(size: 14, weight: .regular, design: .default)

    // MARK: - Caption
    static let clCaption = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Numbers
    static let clNumber = Font.system(size: 24, weight: .heavy, design: .default)
    static let clBigNumber = Font.system(size: 64, weight: .heavy, design: .default)
    static let clTimer = Font.system(size: 48, weight: .heavy, design: .monospaced)
}

extension View {
    func tabularNumbers() -> some View {
        self.monospacedDigit()
    }
}
```

- [ ] **Step 3: ビルドして確認**

Run: Cmd+B
Expected: ビルド成功

- [ ] **Step 4: コミット**

```bash
git add CreateLog/DesignSystem/Colors.swift CreateLog/DesignSystem/Typography.swift
git commit -m "feat: add design system colors and typography"
```

---

### Task 3: デザインシステム — グラスモーフィズム & ハプティクス

**Files:**
- Create: `CreateLog/DesignSystem/GlassModifier.swift`
- Create: `CreateLog/DesignSystem/HapticManager.swift`

- [ ] **Step 1: GlassModifier.swift を作成**

```swift
import SwiftUI

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: HapticManager.swift を作成**

```swift
import UIKit

enum HapticManager {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

- [ ] **Step 3: ビルドして確認**

Run: Cmd+B
Expected: ビルド成功

- [ ] **Step 4: コミット**

```bash
git add CreateLog/DesignSystem/GlassModifier.swift CreateLog/DesignSystem/HapticManager.swift
git commit -m "feat: add glass modifier and haptic manager"
```

---

### Task 4: 共通コンポーネント — カード & アバター

**Files:**
- Create: `CreateLog/DesignSystem/Components/GlassCard.swift`
- Create: `CreateLog/DesignSystem/Components/StatBadge.swift`
- Create: `CreateLog/DesignSystem/Components/AvatarView.swift`
- Create: `CreateLog/DesignSystem/Components/SegmentedControl.swift`

- [ ] **Step 1: GlassCard.swift を作成**

```swift
import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.clSurfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 2: StatBadge.swift を作成**

```swift
import SwiftUI

struct StatBadge: View {
    let value: String
    let label: String
    var change: String? = nil
    var changePositive: Bool = true

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.clNumber)
                    .foregroundStyle(Color.clTextPrimary)
                    .tabularNumbers()

                Text(label)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)

                if let change {
                    Text(change)
                        .font(.clCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(changePositive ? Color.clSuccess : Color.clError)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 3: AvatarView.swift を作成**

```swift
import SwiftUI

enum OnlineStatus {
    case online, coding, offline

    var color: Color {
        switch self {
        case .online: return .clSuccess
        case .coding: return .clRecording
        case .offline: return .clear
        }
    }
}

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    var status: OnlineStatus = .offline

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clSurfaceHigh, Color.clSurfaceLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(Color.clTextSecondary)
                )

            if status != .offline {
                Circle()
                    .fill(status.color)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.clBackground, lineWidth: 2)
                    )
                    .shadow(color: status.color.opacity(0.5), radius: 4)
            }
        }
    }
}
```

- [ ] **Step 4: SegmentedControl.swift を作成**

```swift
import SwiftUI

struct CLSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        selection = index
                    }
                    HapticManager.selection()
                } label: {
                    Text(item)
                        .font(.clHeadline)
                        .foregroundStyle(selection == index ? Color.clTextPrimary : Color.clTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == index
                                ? Color.clSurfaceHigh
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .shadow(
                            color: selection == index ? .black.opacity(0.1) : .clear,
                            radius: 4, y: 2
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 5: ビルドして確認**

Run: Cmd+B
Expected: ビルド成功

- [ ] **Step 6: コミット**

```bash
git add CreateLog/DesignSystem/Components/
git commit -m "feat: add glass card, stat badge, avatar, and segmented control components"
```

---

### Task 5: 共通コンポーネント — フィード & アクション

**Files:**
- Create: `CreateLog/DesignSystem/Components/PostCardView.swift`
- Create: `CreateLog/DesignSystem/Components/ActionButton.swift`
- Create: `CreateLog/DesignSystem/Components/FloatingActionButton.swift`
- Create: `CreateLog/Models/MockData.swift`

- [ ] **Step 1: ActionButton.swift を作成**

```swift
import SwiftUI

struct ActionButton: View {
    let icon: String
    var count: Int? = nil
    var isActive: Bool = false
    var activeColor: Color = .clAccent
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isPressed = true
            }
            HapticManager.light()
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.snappy(duration: 0.2)) {
                    isPressed = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .scaleEffect(isPressed ? 1.3 : 1.0)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.clCaption)
                        .tabularNumbers()
                }
            }
            .foregroundStyle(isActive ? activeColor : Color.clTextTertiary)
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: PostCardView.swift を作成**

```swift
import SwiftUI

struct PostData: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initials: String
    let status: OnlineStatus
    let workTime: String
    let content: String
    let timeAgo: String
    var likes: Int
    var reposts: Int
    var comments: Int
    var isLiked: Bool = false
}

struct PostCardView: View {
    @State var post: PostData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                AvatarView(initials: post.initials, status: post.status)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.name)
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextPrimary)

                        Text("@\(post.handle)")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)

                        Spacer()

                        Text(post.timeAgo)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    // Work time badge
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text("今日")
                            .font(.clCaption)
                        Text(post.workTime)
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextPrimary)
                        Text("作業")
                            .font(.clCaption)
                    }
                    .foregroundStyle(Color.clTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // Content
            Text(post.content)
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
                .lineSpacing(4)
                .padding(.leading, 52)
                .padding(.top, 10)

            // Actions
            HStack(spacing: 0) {
                ActionButton(icon: "bubble.right", count: post.comments) {}

                ActionButton(
                    icon: "arrow.2.squarepath",
                    count: post.reposts,
                    isActive: false,
                    activeColor: .clSuccess
                ) {}

                ActionButton(
                    icon: post.isLiked ? "heart.fill" : "heart",
                    count: post.likes,
                    isActive: post.isLiked,
                    activeColor: .clError
                ) {
                    post.isLiked.toggle()
                    post.likes += post.isLiked ? 1 : -1
                }

                ActionButton(icon: "square.and.arrow.up") {}
            }
            .padding(.leading, 52)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
```

- [ ] **Step 3: FloatingActionButton.swift を作成**

```swift
import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.clTextPrimary)
                .frame(width: 52, height: 52)
                .glassBackground(cornerRadius: 26)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: MockData.swift を作成**

```swift
import Foundation

enum MockData {
    static let posts: [PostData] = [
        PostData(
            name: "田中ゆうき",
            handle: "tanaka_dev",
            initials: "田",
            status: .coding,
            workTime: "3h 20m",
            content: "SwiftUIのアニメーション、やっと理解できてきた。matchedGeometryEffectが最高すぎる #SwiftUI #個人開発",
            timeAgo: "2h",
            likes: 24,
            reposts: 5,
            comments: 3
        ),
        PostData(
            name: "Emily Chen",
            handle: "emily_codes",
            initials: "E",
            status: .online,
            workTime: "5h 45m",
            content: "Just shipped my first Flutter app! The feeling of seeing your creation on the App Store is unreal. 6 months of late nights finally paid off.",
            timeAgo: "4h",
            likes: 89,
            reposts: 8,
            comments: 12
        ),
        PostData(
            name: "佐藤健太",
            handle: "sato_k",
            initials: "佐",
            status: .offline,
            workTime: "1h 10m",
            content: "初心者だけど、毎日30分でもコード書くようにしてる。今日で連続14日目。小さい積み重ねが大事だと信じてる #プログラミング初心者",
            timeAgo: "6h",
            likes: 142,
            reposts: 15,
            comments: 7
        ),
        PostData(
            name: "Alex Kim",
            handle: "alexkim",
            initials: "A",
            status: .coding,
            workTime: "7h 30m",
            content: "Working on a new design system for my SaaS. Trying to nail the dark mode color palette.",
            timeAgo: "8h",
            likes: 31,
            reposts: 2,
            comments: 4
        )
    ]

    static let weeklyHours: [(day: String, hours: Double)] = [
        ("月", 3.2), ("火", 4.8), ("水", 3.5),
        ("木", 6.2), ("金", 5.1), ("土", 2.8), ("日", 4.5)
    ]

    static let categories: [(name: String, hours: Double, color: String)] = [
        ("iOS開発", 12.5, "clAccent"),
        ("Web開発", 8.25, "clTextSecondary"),
        ("学習", 5.0, "clTextTertiary"),
        ("デザイン", 2.75, "clBorder")
    ]
}
```

- [ ] **Step 5: ビルドして確認**

Run: Cmd+B
Expected: ビルド成功

- [ ] **Step 6: コミット**

```bash
git add CreateLog/DesignSystem/Components/ CreateLog/Models/
git commit -m "feat: add post card, action button, FAB, and mock data"
```

---

### Task 6: 共通コンポーネント — グラフ & レポート

**Files:**
- Create: `CreateLog/DesignSystem/Components/WeeklyChart.swift`
- Create: `CreateLog/DesignSystem/Components/CategoryBreakdown.swift`
- Create: `CreateLog/DesignSystem/Components/StreakCard.swift`

- [ ] **Step 1: WeeklyChart.swift を作成**

```swift
import SwiftUI
import Charts

struct WeeklyChart: View {
    let data: [(day: String, hours: Double)]
    var todayIndex: Int = 6

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("週間推移")
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextSecondary)

                Chart(Array(data.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(
                        index == todayIndex
                            ? Color.clAccent
                            : Color.clAccent.opacity(0.3)
                    )
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .frame(height: 140)
            }
        }
    }
}
```

- [ ] **Step 2: CategoryBreakdown.swift を作成**

```swift
import SwiftUI

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let percentage: Double
}

struct CategoryBreakdown: View {
    let categories: [CategoryItem]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("カテゴリ別")
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextSecondary)

                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.clAccent.opacity(1.0 - Double(index) * 0.25))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(category.name)
                                .font(.clHeadline)
                                .foregroundStyle(Color.clTextPrimary)
                            Text(String(format: "%.0fh %02dm", floor(category.hours), Int((category.hours.truncatingRemainder(dividingBy: 1)) * 60)))
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)
                        }

                        Spacer()

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clSurfaceLow)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.clAccent.opacity(1.0 - Double(index) * 0.25),
                                                    Color.clAccent.opacity(0.6 - Double(index) * 0.15)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * category.percentage / 100)
                                }
                        }
                        .frame(width: 100, height: 6)

                        Text("\(Int(category.percentage))%")
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextSecondary)
                            .frame(width: 36, alignment: .trailing)
                            .tabularNumbers()
                    }

                    if index < categories.count - 1 {
                        Divider()
                            .overlay(Color.clBorder)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: StreakCard.swift を作成**

```swift
import SwiftUI

struct StreakCard: View {
    let days: Int
    let weekProgress: [Bool]

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.clAccent)
                    .symbolEffect(.bounce, value: days)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(days)日連続")
                        .font(.clNumber)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()

                    Text("パーソナルベスト更新中")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    HStack(spacing: 3) {
                        ForEach(Array(weekProgress.enumerated()), id: \.offset) { index, completed in
                            Circle()
                                .fill(
                                    completed
                                        ? (index == weekProgress.count - 1
                                            ? Color.clAccent
                                            : Color.clAccent.opacity(0.4))
                                        : Color.clSurfaceLow
                                )
                                .frame(width: 8, height: 8)
                                .shadow(
                                    color: index == weekProgress.count - 1 && completed
                                        ? Color.clAccent.opacity(0.3) : .clear,
                                    radius: 4
                                )
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
    }
}
```

- [ ] **Step 4: ビルドして確認**

Run: Cmd+B
Expected: ビルド成功

- [ ] **Step 5: コミット**

```bash
git add CreateLog/DesignSystem/Components/
git commit -m "feat: add weekly chart, category breakdown, and streak card"
```

---

### Task 7: ホーム画面（フィード）

**Files:**
- Create: `CreateLog/Features/Home/HomeView.swift`

- [ ] **Step 1: HomeView.swift を作成**

```swift
import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Segment
                    CLSegmentedControl(
                        items: ["フォロー中", "おすすめ"],
                        selection: $segmentIndex
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Active now bar
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.clSuccess)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.clSuccess.opacity(0.5), radius: 4)
                            .modifier(PulseModifier())

                        Text("3人")
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextPrimary)
                        + Text("が今作業中")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)

                        Spacer()

                        Image(systemName: "eye")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Feed
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            PostCardView(post: post)

                            if index < posts.count - 1 {
                                Divider()
                                    .overlay(Color.clBorder)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            // FAB
            FloatingActionButton { }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .background(Color.clBackground)
        .navigationTitle("つくろぐ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.light()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }
}

struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.6 : 1.0)
            .scaleEffect(isAnimating ? 0.85 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
```

- [ ] **Step 2: ビルド・シミュレータで確認**

Run: Cmd+R (プレビューまたはシミュレータ)
Expected: フィード画面が表示される。投稿カード、セグメント、ステータスバーが見える

- [ ] **Step 3: コミット**

```bash
git add CreateLog/Features/Home/
git commit -m "feat: add home feed view with posts and active status"
```

---

### Task 8: 記録タブ（タイマー + レポート + カレンダー）

**Files:**
- Create: `CreateLog/Features/Recording/RecordingTabView.swift`
- Create: `CreateLog/Features/Recording/RecordingView.swift`
- Create: `CreateLog/Features/Recording/ReportView.swift`
- Create: `CreateLog/Features/Recording/CalendarView.swift`

- [ ] **Step 1: RecordingTabView.swift を作成**

```swift
import SwiftUI

struct RecordingTabView: View {
    @State private var segmentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            CLSegmentedControl(
                items: ["記録", "レポート", "カレンダー"],
                selection: $segmentIndex
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            TabView(selection: $segmentIndex) {
                RecordingView().tag(0)
                ReportView().tag(1)
                CalendarView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy(duration: 0.3), value: segmentIndex)
        }
        .background(Color.clBackground)
        .navigationTitle("記録")
    }
}
```

- [ ] **Step 2: RecordingView.swift を作成**

```swift
import SwiftUI

struct RecordingView: View {
    @State private var isRecording = false
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?

    var timeString: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Timer
                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.clTimer)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()
                        .contentTransition(.numericText())

                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12))
                        Text("iOS開発")
                            .font(.clCaption)
                    }
                    .foregroundStyle(Color.clTextTertiary)

                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                            isRecording.toggle()
                        }
                        isRecording ? HapticManager.medium() : HapticManager.success()
                        toggleTimer()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    isRecording
                                        ? Color.clError.opacity(0.15)
                                        : Color.clAccent.opacity(0.15)
                                )
                                .frame(width: 64, height: 64)

                            if isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.clError)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.clAccent)
                                    .offset(x: 2)
                            }
                        }
                        .shadow(
                            color: isRecording
                                ? Color.clError.opacity(0.2)
                                : Color.clAccent.opacity(0.2),
                            radius: 12
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.top, 20)

                // VS Code status
                GlassCard {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.clSuccess)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.clSuccess.opacity(0.5), radius: 4)

                        Text("VS Codeで記録中")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextSecondary)

                        Spacer()

                        Text("2h 15m")
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextPrimary)
                            .tabularNumbers()
                    }
                }
                .padding(.horizontal, 20)

                // Today's records
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日の記録")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        recordRow(icon: "chevron.left.forwardslash.chevron.right", name: "UI実装", time: "2h 30m")
                        Divider().overlay(Color.clBorder)
                        recordRow(icon: "ladybug", name: "バグ修正", time: "45m")
                        Divider().overlay(Color.clBorder)
                        recordRow(icon: "book", name: "Swift学習", time: "1h 15m")
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func recordRow(icon: String, name: String, time: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.clTextTertiary)
                .frame(width: 24)

            Text(name)
                .font(.clBody)
                .foregroundStyle(Color.clTextPrimary)

            Spacer()

            Text(time)
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
                .tabularNumbers()
        }
        .padding(.vertical, 12)
    }

    private func toggleTimer() {
        if isRecording {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                elapsedSeconds += 1
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
}
```

- [ ] **Step 3: ReportView.swift を作成**

```swift
import SwiftUI

struct ReportView: View {
    @State private var periodIndex = 1
    @State private var animateNumbers = false

    private let totalCategories: Double = 28.5
    private let categoryItems: [CategoryItem] = [
        CategoryItem(name: "iOS開発", hours: 12.5, percentage: 44),
        CategoryItem(name: "Web開発", hours: 8.25, percentage: 29),
        CategoryItem(name: "学習", hours: 5.0, percentage: 18),
        CategoryItem(name: "デザイン", hours: 2.75, percentage: 9)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero number
                VStack(spacing: 4) {
                    Text("今週のあなた")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    Text(animateNumbers ? "28.5" : "0.0")
                        .font(.clBigNumber)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()
                        .contentTransition(.numericText())

                    Text("時間")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                }
                .padding(.top, 16)

                // Period selector
                HStack(spacing: 4) {
                    ForEach(Array(["今日", "今週", "今月", "累計"].enumerated()), id: \.offset) { index, label in
                        Button {
                            withAnimation(.snappy(duration: 0.3)) {
                                periodIndex = index
                            }
                            HapticManager.selection()
                        } label: {
                            Text(label)
                                .font(.clCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(periodIndex == index ? Color.clTextPrimary : Color.clTextTertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    periodIndex == index ? Color.clSurfaceHigh : Color.clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Streak
                StreakCard(
                    days: 12,
                    weekProgress: [true, true, true, true, true, true, true]
                )
                .padding(.horizontal, 20)

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatBadge(value: "4.5h", label: "今日", change: "↑ 1.2h 昨日比")
                    StatBadge(value: "28.5h", label: "今週", change: "↑ 3h 先週比")
                    StatBadge(value: "1,240h", label: "累計", change: "上位 12%")
                    StatBadge(value: "4.1h", label: "日平均", change: "↓ 0.3h 先週比", changePositive: false)
                }
                .padding(.horizontal, 20)

                // Weekly chart
                WeeklyChart(data: MockData.weeklyHours)
                    .padding(.horizontal, 20)

                // Category breakdown
                CategoryBreakdown(categories: categoryItems)
                    .padding(.horizontal, 20)

                // Share button
                Button {
                    HapticManager.medium()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("レポートをシェア")
                            .font(.clHeadline)
                    }
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                animateNumbers = true
            }
        }
    }
}
```

- [ ] **Step 4: CalendarView.swift を作成**

```swift
import SwiftUI

struct CalendarView: View {
    private let daysInMonth = 31
    private let firstDayOffset = 5 // 3月は土曜日始まり（0=月）
    private let today = 18

    private let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    // ダミー: 各日の作業時間（0 = 記録なし）
    private let dayHours: [Int: Double] = [
        1: 3.2, 2: 4.1, 3: 2.8, 5: 5.0, 6: 3.5,
        8: 4.2, 9: 3.8, 10: 5.5, 11: 4.0, 12: 6.1,
        15: 3.9, 16: 4.5, 17: 5.2, 18: 4.5
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month header
                HStack {
                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer()

                    Text("2026年3月")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Spacer()

                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Day labels
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 3) {
                    ForEach(dayLabels, id: \.self) { day in
                        Text(day)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    // Empty cells for offset
                    ForEach(0..<firstDayOffset, id: \.self) { _ in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }

                    // Days
                    ForEach(1...daysInMonth, id: \.self) { day in
                        let hours = dayHours[day] ?? 0
                        let isToday = day == today
                        let hasData = hours > 0
                        let intensity = min(hours / 8.0, 1.0)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    hasData
                                        ? Color.clAccent.opacity(0.1 + intensity * 0.3)
                                        : Color.clear
                                )
                                .overlay(
                                    isToday
                                        ? RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.clAccent.opacity(0.4), lineWidth: 1.5)
                                        : nil
                                )

                            Text("\(day)")
                                .font(.clCaption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(
                                    isToday ? Color.clTextPrimary
                                    : hasData ? Color.clTextPrimary
                                    : Color.clTextTertiary
                                )
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 20)

                // Monthly summary
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3月のサマリー")
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextSecondary)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("58.3h")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("合計時間")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            VStack(alignment: .leading) {
                                Text("iOS開発")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("最多カテゴリ")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            VStack(alignment: .leading) {
                                Text("3/12")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("ベストデイ")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }
}
```

- [ ] **Step 5: ビルド・シミュレータで確認**

Run: Cmd+R
Expected: 記録タブでセグメント切替が動作し、タイマー・レポート・カレンダーが各表示される

- [ ] **Step 6: コミット**

```bash
git add CreateLog/Features/Recording/
git commit -m "feat: add recording tab with timer, report, and calendar views"
```

---

### Task 9: 残り画面（発見・通知・プロフィール）

**Files:**
- Create: `CreateLog/Features/Discover/DiscoverView.swift`
- Create: `CreateLog/Features/Notifications/NotificationsView.swift`
- Create: `CreateLog/Features/Profile/ProfileView.swift`

- [ ] **Step 1: DiscoverView.swift を作成**

```swift
import SwiftUI

struct DiscoverView: View {
    @State private var searchText = ""

    private let trendingTags = ["SwiftUI", "個人開発", "React", "Flutter", "AI", "TypeScript"]
    private let suggestedUsers = [
        (name: "山田太郎", desc: "iOS開発 3年 / 連続42日", initials: "山"),
        (name: "Emily Chen", desc: "Full Stack / 1200h total", initials: "E"),
        (name: "鈴木一郎", desc: "AI/ML / 今週28h", initials: "鈴")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trending tags
                VStack(alignment: .leading, spacing: 10) {
                    Text("トレンドタグ")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(trendingTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clSurfaceLow, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.clBorder, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Suggested users
                VStack(alignment: .leading, spacing: 12) {
                    Text("おすすめエンジニア")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    ForEach(suggestedUsers, id: \.name) { user in
                        HStack(spacing: 12) {
                            AvatarView(initials: user.initials, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.clHeadline)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text(user.desc)
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Spacer()

                            Button {
                                HapticManager.light()
                            } label: {
                                Text("フォロー")
                                    .font(.clCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.clTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.clSurfaceLow, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Color.clBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)

                        Divider().overlay(Color.clBorder).padding(.leading, 68)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("発見")
        .searchable(text: $searchText, prompt: "ユーザー、タグ、アプリを検索")
    }
}
```

- [ ] **Step 2: NotificationsView.swift を作成**

```swift
import SwiftUI

struct NotificationItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let actor: String
    let message: String
    let time: String
}

struct NotificationsView: View {
    @State private var filterIndex = 0

    private let notifications: [NotificationItem] = [
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "田中", message: "があなたの投稿にいいねしました", time: "3分前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "Emily", message: "があなたをフォローしました", time: "1時間前"),
        NotificationItem(icon: "arrow.2.squarepath", iconColor: .clSuccess, actor: "佐藤", message: "があなたの投稿をリポストしました", time: "3時間前"),
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "yuki", message: "が記録に反応しました", time: "5時間前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "鈴木", message: "があなたをフォローしました", time: "昨日"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CLSegmentedControl(
                    items: ["すべて", "いいね", "フォロー", "メンション"],
                    selection: $filterIndex
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                LazyVStack(spacing: 0) {
                    ForEach(notifications) { notif in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(notif.iconColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: notif.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(notif.iconColor)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                (Text(notif.actor).fontWeight(.semibold).foregroundColor(Color.clTextPrimary)
                                 + Text(notif.message).foregroundColor(Color.clTextSecondary))
                                    .font(.clBody)

                                Text(notif.time)
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        Divider().overlay(Color.clBorder).padding(.leading, 68)
                    }
                }
                .padding(.top, 12)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("通知")
    }
}
```

- [ ] **Step 3: ProfileView.swift を作成**

```swift
import SwiftUI

struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Avatar & info
                VStack(spacing: 8) {
                    AvatarView(initials: "S", size: 72, status: .online)

                    Text("San")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Text("@san_dev")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    Text("iOS / Web エンジニア")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)

                    // Stats row
                    HStack(spacing: 24) {
                        profileStat(value: "120", label: "フォロワー")
                        profileStat(value: "85", label: "フォロー")
                        profileStat(value: "1,240h", label: "累計")
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 16)

                // Mini chart
                WeeklyChart(data: MockData.weeklyHours)
                    .padding(.horizontal, 20)

                // My apps
                VStack(alignment: .leading, spacing: 12) {
                    Text("マイアプリ")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .padding(.horizontal, 20)

                    appCard(name: "つくろぐ", desc: "エンジニアの記録プラットフォーム")
                    appCard(name: "FocusFlow", desc: "ポモドーロタイマー")
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.light()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.clHeadline)
                .foregroundStyle(Color.clTextPrimary)
                .tabularNumbers()
            Text(label)
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    private func appCard(name: String, desc: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.clSurfaceHigh, Color.clSurfaceLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextPrimary)
                Text(desc)
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
```

- [ ] **Step 4: ビルド・シミュレータで確認**

Run: Cmd+R
Expected: 各画面が表示される

- [ ] **Step 5: コミット**

```bash
git add CreateLog/Features/
git commit -m "feat: add discover, notifications, and profile views"
```

---

### Task 10: タブ構成 & アプリエントリポイント

**Files:**
- Modify: `CreateLog/CreateLogApp.swift` (or `ContentView.swift`)

- [ ] **Step 1: メインのタブ構成を作成**

`CreateLogApp.swift`（またはContentView.swift）を以下に置き換え:

```swift
import SwiftUI

@main
struct CreateLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("ホーム", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Label("発見", systemImage: "magnifyingglass")
            }
            .tag(1)

            NavigationStack {
                RecordingTabView()
            }
            .tabItem {
                Label("記録", systemImage: selectedTab == 2 ? "record.circle.fill" : "record.circle")
            }
            .tag(2)

            NavigationStack {
                NotificationsView()
            }
            .tabItem {
                Label("通知", systemImage: selectedTab == 3 ? "bell.fill" : "bell")
            }
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("マイ", systemImage: selectedTab == 4 ? "person.fill" : "person")
            }
            .tag(4)
        }
        .tint(Color.clAccent)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}
```

- [ ] **Step 2: ビルド・シミュレータで全画面確認**

Run: Cmd+R (iPhone 16 Pro Simulator)
Expected: 5タブが表示され、全画面が遷移可能。ダーク/ライト切り替えでカラーが反転する。

確認項目:
- タブ切替でハプティクスが鳴る
- フィードの投稿カードが表示される
- いいねボタンのアニメーションが動く
- レポートの数字がカウントアップする
- タイマーが動作する
- カレンダーのヒートマップが表示される
- セグメント切替がスムーズ

- [ ] **Step 3: ライトモードも確認**

`CreateLogApp.swift`の`.preferredColorScheme(.dark)`を削除して、システム設定に追従するようにする。シミュレータの設定 > Appearance > Light に変更して確認。

- [ ] **Step 4: コミット**

```bash
git add CreateLog/
git commit -m "feat: add main tab view with all 5 tabs wired up"
```

---

## 完了条件

- [ ] シミュレータで5タブ全てが表示される
- [ ] ダーク/ライトモード両方でカラーが正しい
- [ ] タブ切替、セグメント切替にハプティクスが鳴る
- [ ] いいねボタンにアニメーションがある
- [ ] タイマーが動作する
- [ ] レポートの数字がカウントアップする
- [ ] カレンダーのヒートマップが色分け表示される
- [ ] グラフ（Swift Charts）が表示される
