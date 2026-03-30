# ファイル構造リファクタリング Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Feature内をViews/ViewModelsに分離し、モデル定義をViewファイルから独立させ、DesignSystem内のドメインモデルを適切な場所に移動する

**Architecture:** Feature-Grouped Clean MVVM。各Feature内にViews/ViewModels/(Models)サブフォルダを持つ。共有ドメインモデルはModels/に昇格。DesignSystemはUIコンポーネントのみに限定する。ViewModelは`@MainActor @Observable`パターン (Swift 6.2対応)

**Tech Stack:** SwiftUI, XcodeGen (project.yml), iOS 26.0

**Note:** テストターゲットなし (CLAUDE.md記載)。TDDは適用外。各タスク後にビルド確認で検証する。

---

## ファイル構造マップ

### Before (現状)
```
CreateLog/
├── CreateLogApp.swift              # @main + MainTabView (37行)
├── Models/
│   └── MockData.swift              # PostDataのモックデータ (114行)
├── Features/
│   ├── Home/
│   │   └── HomeView.swift          # View + PulseModifier (158行)
│   ├── Discover/
│   │   └── DiscoverView.swift      # 型定義 + モック + View + MasonryGrid + DiscoverCard (414行)
│   ├── Recording/
│   │   ├── RecordingTabView.swift   # コンテナView (26行)
│   │   ├── RecordingView.swift      # View + タイマーロジック (149行)
│   │   ├── ReportView.swift         # View + CategoryItem定義重複 (116行)
│   │   └── CalendarView.swift       # View + ハードコードデータ (146行)
│   ├── Notifications/
│   │   └── NotificationsView.swift  # NotificationItem定義 + View + モック (72行)
│   └── Profile/
│       └── ProfileView.swift        # View (109行)
└── DesignSystem/
    ├── Colors.swift, Typography.swift, GlassModifier.swift, HapticManager.swift
    └── Components/
        ├── PostCardView.swift       # PostData定義 + PostCardView (143行) ← ドメインモデルがここにある
        ├── AvatarView.swift         # OnlineStatus定義 + AvatarView (69行) ← ドメインモデルがここにある
        ├── CategoryBreakdown.swift  # CategoryItem定義 + View (73行) ← ドメインモデルがここにある
        └── (他8コンポーネント)
```

### After (目標)
```
CreateLog/
├── App/
│   ├── CreateLogApp.swift           # @mainエントリのみ
│   └── MainTabView.swift            # タブ構造
├── Models/
│   ├── Post.swift                   # PostData (元PostCardView.swift内)
│   ├── OnlineStatus.swift           # OnlineStatus (元AvatarView.swift内)
│   ├── CategoryItem.swift           # CategoryItem (元CategoryBreakdown.swift内)
│   ├── DiscoverItem.swift           # DiscoverItem + enum (元DiscoverView.swift内)
│   ├── NotificationItem.swift       # NotificationItem (元NotificationsView.swift内)
│   └── MockData.swift               # 全モックデータ集約
├── Features/
│   ├── Home/
│   │   └── Views/
│   │       └── HomeView.swift
│   ├── Discover/
│   │   └── Views/
│   │       ├── DiscoverView.swift   # UIのみ (~85行)
│   │       ├── MasonryGrid.swift    # レイアウト (~50行)
│   │       └── DiscoverCard.swift   # カードUI (~130行)
│   ├── Recording/
│   │   └── Views/
│   │       ├── RecordingTabView.swift
│   │       ├── RecordingView.swift
│   │       ├── ReportView.swift
│   │       └── CalendarView.swift
│   ├── Notifications/
│   │   └── Views/
│   │       └── NotificationsView.swift
│   └── Profile/
│       └── Views/
│           └── ProfileView.swift
├── DesignSystem/
│   ├── Tokens/
│   │   ├── Colors.swift
│   │   └── Typography.swift
│   ├── Components/
│   │   ├── PostCardView.swift       # Viewのみ (PostData定義は削除済み)
│   │   ├── AvatarView.swift         # Viewのみ (OnlineStatus定義は削除済み)
│   │   ├── CategoryBreakdown.swift  # Viewのみ (CategoryItem定義は削除済み)
│   │   └── (他コンポーネント)
│   ├── Modifiers/
│   │   ├── GlassModifier.swift
│   │   └── PulseModifier.swift      # HomeView.swiftから抽出
│   └── Utilities/
│       └── HapticManager.swift       # ViewModifierではなくユーティリティ
```

### 変更方針
- **ドメインモデル (PostData, OnlineStatus, CategoryItem等) をDesignSystem/Components内のViewファイルから `Models/` に移動** --- DesignSystemはUIのみに限定
- **Feature内の型定義 (DiscoverItem, NotificationItem) も `Models/` に移動** --- Viewファイルをスリムに
- **DiscoverView.swift (414行) を3ファイルに分割** --- 責務分離
- **CreateLogApp.swift からMainTabViewを分離** --- エントリポイントの責務最小化
- **DesignSystem内をTokens/Components/Modifiersに整理** --- 種類別に探しやすく
- **Feature内にViews/サブフォルダ** --- 将来のViewModels追加の受け皿
- **project.ymlは変更不要** --- `sources: CreateLog` でフォルダ内全.swiftを自動取得

---

### Task 1: ドメインモデルをModels/に抽出し、元ファイルから削除 (アトミックに実行)

**Files:**
- Create: `CreateLog/Models/Post.swift`
- Create: `CreateLog/Models/OnlineStatus.swift`
- Create: `CreateLog/Models/CategoryItem.swift`
- Create: `CreateLog/Models/DiscoverItem.swift`
- Create: `CreateLog/Models/NotificationItem.swift`
- Modify: `CreateLog/DesignSystem/Components/PostCardView.swift` (L3-16のPostData定義を削除)
- Modify: `CreateLog/DesignSystem/Components/AvatarView.swift` (L3-12のOnlineStatus定義を削除)
- Modify: `CreateLog/DesignSystem/Components/CategoryBreakdown.swift` (L3-8のCategoryItem定義を削除)
- Modify: `CreateLog/Features/Discover/DiscoverView.swift` (L3-142の型定義+モックデータを削除)
- Modify: `CreateLog/Features/Notifications/NotificationsView.swift` (L3-10のNotificationItem定義を削除)
- Modify: `CreateLog/Models/MockData.swift` (discoverItems, notificationsモックを追加)

**重要:** Steps 1-12は全てビルド前にアトミックに完了すること。途中でビルドすると重複定義エラーになる。

- [ ] **Step 1: `Models/Post.swift` を作成**

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
```

- [ ] **Step 2: `Models/OnlineStatus.swift` を作成**

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
```

- [ ] **Step 3: `Models/CategoryItem.swift` を作成**

```swift
import Foundation

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let percentage: Double
}
```

- [ ] **Step 4: `Models/DiscoverItem.swift` を作成**

```swift
import SwiftUI

enum DiscoverContentType {
    case project
    case article
    case video
    case codeSnippet
}

enum DiscoverCardSize {
    case small  // 1x1
    case tall   // 1x2 (tall)
    case wide   // takes full width occasionally
}

struct DiscoverItem: Identifiable {
    let id = UUID()
    let type: DiscoverContentType
    let size: DiscoverCardSize
    let title: String
    let subtitle: String
    let authorName: String
    let authorInitials: String
    let color: Color // placeholder for image
    let iconName: String
    let metric: String
}
```

- [ ] **Step 5: `Models/NotificationItem.swift` を作成**

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
```

- [ ] **Step 6: PostCardView.swiftからPostData定義を削除**

`PostCardView.swift`のL3-16 (`struct PostData: Identifiable { ... }`) と直後の空行を削除。`import SwiftUI` と `PostCardView` struct はそのまま残す。

- [ ] **Step 7: AvatarView.swiftからOnlineStatus定義を削除**

`AvatarView.swift`のL3-12 (`enum OnlineStatus { ... }`) と直後の空行を削除。`import SwiftUI` と `AvatarView` struct はそのまま残す。

- [ ] **Step 8: CategoryBreakdown.swiftからCategoryItem定義を削除**

`CategoryBreakdown.swift`のL3-8 (`struct CategoryItem: Identifiable { ... }`) と直後の空行を削除。`import SwiftUI` と `CategoryBreakdown` struct はそのまま残す。

- [ ] **Step 9: DiscoverView.swiftからモデル定義+モックデータを削除**

**L3-142を削除** (L1の`import SwiftUI`とL2の空行は残す)。型定義3つ (`DiscoverContentType`, `DiscoverCardSize`, `DiscoverItem`) と `discoverItems` モックデータ配列を全て削除。

- [ ] **Step 10: NotificationsView.swiftからNotificationItem定義を削除**

`NotificationsView.swift`のL3-10 (`struct NotificationItem: Identifiable { ... }`) と直後の空行を削除。

- [ ] **Step 11: MockData.swiftにdiscoverItemsとnotificationsを追加**

`Models/MockData.swift` の `enum MockData` 内に以下を追加:

```swift
    static let discoverItems: [DiscoverItem] = [
        DiscoverItem(
            type: .project, size: .tall,
            title: "Tempo",
            subtitle: "SwiftUIで作った習慣トラッカー",
            authorName: "田中ゆうき", authorInitials: "田",
            color: Color(red: 0.2, green: 0.25, blue: 0.45),
            iconName: "hammer.fill",
            metric: "182"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "SwiftUIで作るカスタムチャート",
            subtitle: "Charts不要の実装法",
            authorName: "佐藤健太", authorInitials: "佐",
            color: Color(red: 0.15, green: 0.2, blue: 0.3),
            iconName: "doc.text.fill",
            metric: "324"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Flutter vs SwiftUI 2026",
            subtitle: "12:34",
            authorName: "Emily Chen", authorInitials: "E",
            color: Color(red: 0.3, green: 0.18, blue: 0.25),
            iconName: "play.fill",
            metric: "1.2K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "async/await エラーハンドリング",
            subtitle: "Swift Concurrency",
            authorName: "高橋リョウ", authorInitials: "高",
            color: Color(red: 0.12, green: 0.18, blue: 0.22),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "89"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "FocusFlow",
            subtitle: "集中タイマーを個人開発中",
            authorName: "Alex Kim", authorInitials: "A",
            color: Color(red: 0.25, green: 0.15, blue: 0.35),
            iconName: "hammer.fill",
            metric: "67"
        ),
        DiscoverItem(
            type: .article, size: .tall,
            title: "個人開発で月10万円稼ぐまでの全記録",
            subtitle: "収益化の実体験",
            authorName: "Maria Santos", authorInitials: "M",
            color: Color(red: 0.18, green: 0.22, blue: 0.18),
            iconName: "doc.text.fill",
            metric: "2.1K"
        ),
        DiscoverItem(
            type: .video, size: .tall,
            title: "0からiOSアプリをリリースするまで",
            subtitle: "45:12",
            authorName: "Jake Wilson", authorInitials: "J",
            color: Color(red: 0.28, green: 0.15, blue: 0.15),
            iconName: "play.fill",
            metric: "5.6K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "matchedGeometryEffect 実践パターン",
            subtitle: "SwiftUI Animation",
            authorName: "鈴木一郎", authorInitials: "鈴",
            color: Color(red: 0.1, green: 0.15, blue: 0.2),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "156"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "CodeLog",
            subtitle: "開発記録を残すアプリを作ってます",
            authorName: "Yuki Tanaka", authorInitials: "Y",
            color: Color(red: 0.2, green: 0.2, blue: 0.35),
            iconName: "hammer.fill",
            metric: "93"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "Supabase認証完全ガイド",
            subtitle: "SwiftUI + Auth",
            authorName: "田中ゆうき", authorInitials: "田",
            color: Color(red: 0.15, green: 0.25, blue: 0.2),
            iconName: "doc.text.fill",
            metric: "890"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Rust入門 ライブコーディング",
            subtitle: "1:23:45",
            authorName: "高橋リョウ", authorInitials: "高",
            color: Color(red: 0.22, green: 0.12, blue: 0.18),
            iconName: "play.fill",
            metric: "3.4K"
        ),
        DiscoverItem(
            type: .project, size: .tall,
            title: "DevBoard",
            subtitle: "React + Supabaseでダッシュボード開発中",
            authorName: "Alex Kim", authorInitials: "A",
            color: Color(red: 0.15, green: 0.2, blue: 0.32),
            iconName: "hammer.fill",
            metric: "241"
        ),
    ]

    static let notifications: [NotificationItem] = [
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "田中", message: "があなたの投稿にいいねしました", time: "3分前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "Emily", message: "があなたをフォローしました", time: "1時間前"),
        NotificationItem(icon: "arrow.2.squarepath", iconColor: .clSuccess, actor: "佐藤", message: "があなたの投稿をリポストしました", time: "3時間前"),
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "yuki", message: "が記録に反応しました", time: "5時間前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "鈴木", message: "があなたをフォローしました", time: "昨日"),
    ]
```

- [ ] **Step 12: DiscoverView.swiftとNotificationsView.swiftの参照を更新**

DiscoverView.swift: `MasonryGrid(items: discoverItems)` → `MasonryGrid(items: MockData.discoverItems)`

NotificationsView.swift: `private let notifications: [NotificationItem] = [...]` (インライン定義) → `private let notifications = MockData.notifications`

- [ ] **Step 13: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 14: コミット**

```bash
git add CreateLog/Models/ CreateLog/DesignSystem/Components/PostCardView.swift CreateLog/DesignSystem/Components/AvatarView.swift CreateLog/DesignSystem/Components/CategoryBreakdown.swift CreateLog/Features/Discover/DiscoverView.swift CreateLog/Features/Notifications/NotificationsView.swift
git commit -m "refactor: extract domain models from View files into Models/"
```

---

### Task 3: DiscoverView.swift を3ファイルに分割

**Files:**
- Modify: `CreateLog/Features/Discover/DiscoverView.swift` (DiscoverView struct のみ残す)
- Create: `CreateLog/Features/Discover/MasonryGrid.swift` (MasonryGrid を独立)
- Create: `CreateLog/Features/Discover/DiscoverCard.swift` (DiscoverCard を独立)

**重要:** 新ファイル作成 (Steps 1-2) と元ファイルからの削除 (Step 3) はビルド前に全て完了すること。新ファイルだけ作って元を消さないと重複定義エラーになる。

- [ ] **Step 1: `MasonryGrid.swift` を作成**

DiscoverView.swiftの `MasonryGrid` struct を新ファイルに移動。`private` を削除して `internal` (デフォルト) に変更 (別ファイルからアクセスするため):

```swift
import SwiftUI

struct MasonryGrid: View {
    let items: [DiscoverItem]

    var body: some View {
        let (left, right) = distributeItems(items)
        HStack(alignment: .top, spacing: 10) {
            LazyVStack(spacing: 10) {
                ForEach(left) { item in
                    DiscoverCard(item: item)
                }
            }
            LazyVStack(spacing: 10) {
                ForEach(right) { item in
                    DiscoverCard(item: item)
                }
            }
        }
    }

    private func distributeItems(_ items: [DiscoverItem]) -> ([DiscoverItem], [DiscoverItem]) {
        var left: [DiscoverItem] = []
        var right: [DiscoverItem] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        for item in items {
            let h = cardHeight(item)
            if leftHeight <= rightHeight {
                left.append(item)
                leftHeight += h + 10
            } else {
                right.append(item)
                rightHeight += h + 10
            }
        }
        return (left, right)
    }

    private func cardHeight(_ item: DiscoverItem) -> CGFloat {
        switch item.size {
        case .small: return 180
        case .tall: return 280
        case .wide: return 180
        }
    }
}
```

- [ ] **Step 2: `DiscoverCard.swift` を作成**

DiscoverView.swiftのL286-414 (`DiscoverCard` struct) を新ファイルに移動。`private` を `internal` に変更。

metricLabelの重複コードを修正 (.project と .article/.codeSnippet が同一):

```swift
@ViewBuilder
private var metricLabel: some View {
    let icon = item.type == .video ? "eye.fill" : "heart.fill"
    HStack(spacing: 2) {
        Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundStyle(Color.clTextTertiary)
        Text(item.metric)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.clTextTertiary)
    }
}
```

- [ ] **Step 3: DiscoverView.swiftからMasonryGridとDiscoverCardを削除**

DiscoverView.swiftにはDiscoverView structのみ残す。約85行になる。

- [ ] **Step 4: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: コミット**

```bash
git add CreateLog/Features/Discover/
git commit -m "refactor: split DiscoverView into DiscoverView, MasonryGrid, DiscoverCard

Also deduplicate metricLabel in DiscoverCard (.project and .article/.codeSnippet had identical code)."
```

---

### Task 4: App/ フォルダ分離 + MainTabView独立

**Files:**
- Move: `CreateLog/CreateLogApp.swift` → `CreateLog/App/CreateLogApp.swift`
- Create: `CreateLog/App/MainTabView.swift`

- [ ] **Step 1: git mvでCreateLogApp.swiftをApp/に移動**

```bash
mkdir -p CreateLog/App
git mv CreateLog/CreateLogApp.swift CreateLog/App/CreateLogApp.swift
```

- [ ] **Step 2: `App/MainTabView.swift` を作成**

CreateLogApp.swiftからMainTabView structを新ファイルに抽出:

```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var tabBarOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clBackground
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView(tabBarOffset: $tabBarOffset) }
                case 1: NavigationStack { DiscoverView(tabBarOffset: $tabBarOffset) }
                case 2: NavigationStack { RecordingTabView() }
                case 3: NavigationStack { NotificationsView() }
                case 4: NavigationStack { ProfileView() }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .offset(y: tabBarOffset)
        }
    }
}
```

- [ ] **Step 3: `App/CreateLogApp.swift` からMainTabViewを削除**

移動済みの `CreateLog/App/CreateLogApp.swift` を編集し、MainTabView structを削除してエントリのみ残す:

```swift
import SwiftUI

@main
struct CreateLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
```

- [ ] **Step 4: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: コミット**

```bash
git add CreateLog/App/
git commit -m "refactor: separate MainTabView from app entry point into App/"
```

---

### Task 5: DesignSystem内のフォルダ整理 (Tokens/Modifiers/Utilities分離)

**Files:**
- Move: `CreateLog/DesignSystem/Colors.swift` → `CreateLog/DesignSystem/Tokens/Colors.swift`
- Move: `CreateLog/DesignSystem/Typography.swift` → `CreateLog/DesignSystem/Tokens/Typography.swift`
- Move: `CreateLog/DesignSystem/GlassModifier.swift` → `CreateLog/DesignSystem/Modifiers/GlassModifier.swift`
- Move: `CreateLog/DesignSystem/HapticManager.swift` → `CreateLog/DesignSystem/Utilities/HapticManager.swift`
- Create: `CreateLog/DesignSystem/Modifiers/PulseModifier.swift` (HomeView.swiftから抽出)

- [ ] **Step 1: Tokens/ フォルダにColors.swiftとTypography.swiftを移動**

```bash
mkdir -p CreateLog/DesignSystem/Tokens
git mv CreateLog/DesignSystem/Colors.swift CreateLog/DesignSystem/Tokens/Colors.swift
git mv CreateLog/DesignSystem/Typography.swift CreateLog/DesignSystem/Tokens/Typography.swift
```

- [ ] **Step 2: Modifiers/ フォルダにGlassModifier.swiftを移動、Utilities/ にHapticManager.swiftを移動**

HapticManagerはViewModifierではなくユーティリティクラス (static func群) なのでUtilities/に配置。

```bash
mkdir -p CreateLog/DesignSystem/Modifiers CreateLog/DesignSystem/Utilities
git mv CreateLog/DesignSystem/GlassModifier.swift CreateLog/DesignSystem/Modifiers/GlassModifier.swift
git mv CreateLog/DesignSystem/HapticManager.swift CreateLog/DesignSystem/Utilities/HapticManager.swift
```

- [ ] **Step 3: PulseModifier.swift をHomeView.swiftから抽出**

HomeView.swiftのL145-158 (`PulseModifier` struct) を新ファイルに:

```swift
import SwiftUI

struct PulseModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .scaleEffect(isAnimating ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}
```

HomeView.swiftからPulseModifier定義を削除。

- [ ] **Step 4: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: コミット**

```bash
git add CreateLog/DesignSystem/ CreateLog/Features/Home/HomeView.swift
git commit -m "refactor: organize DesignSystem into Tokens/Components/Modifiers/Utilities"
```

---

### Task 6: Feature内にViews/ サブフォルダを作成してファイルを移動

**Files:**
- Move: 各Feature内の.swiftファイルをViews/サブフォルダに移動

- [ ] **Step 1: Home**

```bash
mkdir -p CreateLog/Features/Home/Views
git mv CreateLog/Features/Home/HomeView.swift CreateLog/Features/Home/Views/HomeView.swift
```

- [ ] **Step 2: Discover**

```bash
mkdir -p CreateLog/Features/Discover/Views
git mv CreateLog/Features/Discover/DiscoverView.swift CreateLog/Features/Discover/Views/DiscoverView.swift
git mv CreateLog/Features/Discover/MasonryGrid.swift CreateLog/Features/Discover/Views/MasonryGrid.swift
git mv CreateLog/Features/Discover/DiscoverCard.swift CreateLog/Features/Discover/Views/DiscoverCard.swift
```

- [ ] **Step 3: Recording**

```bash
mkdir -p CreateLog/Features/Recording/Views
git mv CreateLog/Features/Recording/RecordingTabView.swift CreateLog/Features/Recording/Views/RecordingTabView.swift
git mv CreateLog/Features/Recording/RecordingView.swift CreateLog/Features/Recording/Views/RecordingView.swift
git mv CreateLog/Features/Recording/ReportView.swift CreateLog/Features/Recording/Views/ReportView.swift
git mv CreateLog/Features/Recording/CalendarView.swift CreateLog/Features/Recording/Views/CalendarView.swift
```

- [ ] **Step 4: Notifications**

```bash
mkdir -p CreateLog/Features/Notifications/Views
git mv CreateLog/Features/Notifications/NotificationsView.swift CreateLog/Features/Notifications/Views/NotificationsView.swift
```

- [ ] **Step 5: Profile**

```bash
mkdir -p CreateLog/Features/Profile/Views
git mv CreateLog/Features/Profile/ProfileView.swift CreateLog/Features/Profile/Views/ProfileView.swift
```

- [ ] **Step 6: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 7: コミット**

```bash
git add CreateLog/Features/
git commit -m "refactor: move Feature views into Views/ subfolders"
```

---

### Task 7: ReportView.swiftのCategoryItem重複データをMockDataに統合

**Files:**
- Modify: `CreateLog/Features/Recording/Views/ReportView.swift`
- Modify: `CreateLog/Models/MockData.swift`

- [ ] **Step 1: MockData.swiftにcategoryItemsを追加**

```swift
static let categoryItems: [CategoryItem] = [
    CategoryItem(name: "iOS開発", hours: 12.5, percentage: 44),
    CategoryItem(name: "Web開発", hours: 8.25, percentage: 29),
    CategoryItem(name: "学習", hours: 5.0, percentage: 18),
    CategoryItem(name: "デザイン", hours: 2.75, percentage: 9)
]
```

既存の `categories` (String tuple版) は `MockData.weeklyHours` と同様に残してもよいが、`CategoryItem`版と重複するため削除する。

- [ ] **Step 2: ReportView.swiftのローカルcategoryItems定義を削除**

`private let categoryItems` (L8-13) を削除し、body内の参照を `MockData.categoryItems` に変更。`totalCategories` 定数もMockDataから算出するか、そのまま残す (UIの表示用なのでViewに残してOK)。

- [ ] **Step 3: ビルド確認**

Run: `cd /Users/個人開発/createlog-ios/createlog-ios && xcodegen generate && xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: コミット**

```bash
git add CreateLog/Models/MockData.swift CreateLog/Features/Recording/Views/ReportView.swift
git commit -m "refactor: consolidate CategoryItem mock data into MockData"
```

---

## 最終構造確認

全タスク完了後のファイルツリー:

```
CreateLog/
├── App/
│   ├── CreateLogApp.swift           # @main (10行)
│   └── MainTabView.swift            # タブ構造 (27行)
├── Models/
│   ├── Post.swift                   # PostData
│   ├── OnlineStatus.swift           # OnlineStatus enum
│   ├── CategoryItem.swift           # CategoryItem
│   ├── DiscoverItem.swift           # DiscoverItem + enums
│   ├── NotificationItem.swift       # NotificationItem
│   └── MockData.swift               # 全モックデータ集約
├── Features/
│   ├── Home/
│   │   └── Views/
│   │       └── HomeView.swift       # (~145行, PulseModifier抽出済み)
│   ├── Discover/
│   │   └── Views/
│   │       ├── DiscoverView.swift   # (~85行)
│   │       ├── MasonryGrid.swift    # (~50行)
│   │       └── DiscoverCard.swift   # (~125行)
│   ├── Recording/
│   │   └── Views/
│   │       ├── RecordingTabView.swift
│   │       ├── RecordingView.swift
│   │       ├── ReportView.swift
│   │       └── CalendarView.swift
│   ├── Notifications/
│   │   └── Views/
│   │       └── NotificationsView.swift
│   └── Profile/
│       └── Views/
│           └── ProfileView.swift
├── DesignSystem/
│   ├── Tokens/
│   │   ├── Colors.swift
│   │   └── Typography.swift
│   ├── Components/
│   │   ├── PostCardView.swift       # Viewのみ
│   │   ├── AvatarView.swift         # Viewのみ
│   │   ├── CategoryBreakdown.swift  # Viewのみ
│   │   ├── SegmentedControl.swift
│   │   ├── CustomTabBar.swift
│   │   ├── GlassCard.swift
│   │   ├── StatBadge.swift
│   │   ├── ActionButton.swift
│   │   ├── WeeklyChart.swift
│   │   ├── StreakCard.swift
│   │   └── FloatingActionButton.swift
│   ├── Modifiers/
│   │   ├── GlassModifier.swift
│   │   └── PulseModifier.swift
│   └── Utilities/
│       └── HapticManager.swift
└── Assets.xcassets/
```

ViewModelsフォルダは今は作らない。Supabase統合時に各Feature内にViewModels/を追加する。
