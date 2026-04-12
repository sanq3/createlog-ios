---
description: Swiftファイル編集時のアーキテクチャ・コード規約
globs: ["**/*.swift"]
---

# アーキテクチャ・コード規約

## レイヤー構成

View → ViewModel(@Observable) → Repository/Service → Supabase

- Viewにロジックを書かない。状態管理はViewModel(@Observable)に分離
- ViewModelには `@MainActor @Observable` を付ける (Swift 6.2対応)
- Supabaseへの直接アクセスはRepository層に閉じる。Viewから直接クエリしない
- Viewに@Stateでドメインロジックを持たせない

## ファイル構成

- Models/は `import Foundation` のみ。SwiftUIをimportしない
- モデルにColor/Image等のUI型を持たせない。UI変換はDesignSystem/Extensions/に書く
- Viewファイルにモデル定義を書かない。Models/に独立ファイルで置く
- 1ファイル1責務。200行を超えたら分割を検討する
- 重複ロジックは共通Modifier/Extension/関数に抽出する
- 新Featureは `Features/{Name}/Views/` に作る。ViewModelが必要になったら `ViewModels/` を追加

## コーディングルール

- iPhone縦固定。XcodeGen (`project.yml`) でプロジェクト管理
- 色・フォントは `cl` プレフィックスのデザイントークンを使う（ハードコード禁止）
- カテゴリ色は 1 箇所で定義しろ: Asset Catalog に `clCat01`〜`clCat12` をライト/ダーク両対応で置き、`LogEntry.color(for:)` 静的メソッドで全画面から参照する。画面ごとに色を定義するな
- アニメーション: spring(duration 0.35, bounce 0.15-0.3)
- 機密情報はxcconfig or 環境変数。コードに埋め込まない
- 認証状態はSupabase Auth / Keychain。UserDefaultsに保存しない

## Design Direction

差別化はビジュアル品質のみで出す。UXパターンは大手SNS(X, Instagram等)を踏襲して再発明するな。操作体系・タブ構成・スクロール挙動・カード構造・ジェスチャーは既存の検証済みパターンを使え。独自性はデザイントークン、色彩、タイポグラフィ、マテリアル、アニメーションの質感で出せ。

### Liquid Glass全面採用

- iOS 26 Liquid Glass を全画面で適用しろ。ヘッダー、カード、シート、ボタンに使え
- タブバーのみ自作(スクロール連動で隠す必要があり純正TabViewでは不可)。glassEffect風の見た目で自作する
- 色基調(ライト=白、ダーク=黒)は変えない

### アイコン運用ルール

SF Symbols は「安っぽく見えない」用途に限定しろ。アイコンを過剰に並べてチープに見せるな。

**使ってよい用途:**
- 標準アクション (いいね, シェア, ブックマーク, 閉じる, 検索, メニュー, コメント, 送信)
- ナビゲーション (戻る, 進む, chevron)
- タブバー・コンテキストメニューの Label
- フォーム要素 (チェックマーク, クリアボタン, カメラ)
- 通知タイプ識別バッジ

**使うな:**
- コンテンツの装飾 (bolt.fill, flame.fill 等の意味のない飾り)
- テキストだけで十分伝わる箇所への不要なアイコン追加
- emoji を立場・役割の表現に使う

**補足:**
- プラットフォーム表示はテキスト「iOS」「Android」「Web」で表現しろ
- アプリ名表記: 日本語「つくろぐ」/ 英語「CreateLog」

### 色・ビジュアルを発明するな

- UIの色を自分の感覚で作るな。必ず実在アプリ(Toggl Track, Apple Health, GitHub, Linear等)やデザインシステム(Apple HIG, Material Design, Tailwind)から調査して適用しろ
- RGB値を手打ちで発明するな
- 調査結果から候補を提示しユーザーに選ばせろ

### ゲーミフィケーション禁止

- 記録タブにストリーク・デイリーゴール・プログレスリング・confetti等を入れるな。コーディングは毎日やるものではない(平日のみ/週末のみ/不定期もある)
- 「連続○日」はやらなかった日に罪悪感を与えるだけ。このアプリは「やった時間を淡々と記録する道具」
- 記録タブの改善は「既存機能の見た目と手触りの質を上げる」に限定する。機能追加ではなくビジュアルポリッシュ

### UI参考時はモーションまで再現

参考UIを実装する前に必ず以下を確認しろ:
1. メインコンテンツの動き(一緒にスライドするか、固定か)
2. パララックス効果の有無
3. ジェスチャーの検出範囲と追従の滑らかさ
4. トランジションの方向と速度

機能の表面だけコピーするな。連動スライド・パララックス・追従感まで正確に再現しろ。

### スクロール連動バーのしきい値

タブバー/ヘッダーのスクロール表示非表示は X (Twitter) の挙動に従え:
- 上下どちらも 1:1 追従(大きな resistance を入れるな。ノイズフィルタのみ)
- 途中まで出る/隠れる中間状態を持つ
- 指を離した時: 50%以上隠れていたら隠す、50%未満なら表示にスナップ

`ScrollHideModifier` に大きなしきい値を入れるな。

## 拡張性

### Protocol抽象化

- Repository/Serviceは必ずprotocolを先に定義し、それから実装を書く。protocolなしの具象Serviceは禁止
- protocolは`Models/`に置く（`import Foundation`のみ）。実装は将来の`Services/`層に置く
- protocolには`Sendable`を付ける（Swift 6 strict concurrency対応）
- 1 protocolに5メソッド以上入れない。肥大化したら責務で分割する

### Dependency Injection

- 依存はすべて`init`で受け取る（Constructor Injection）。シングルトン参照やプロパティ直接代入は禁止
- ViewModelの依存プロパティには`@ObservationIgnored`を付ける。依存オブジェクト変更でViewが再描画されるのを防ぐ
- ViewModelの依存は最大4つ。超えたら責務分割のサイン
- 具象型の生成はComposition Root（App層）に集約する。Feature内で具象型をインスタンス化しない
- View階層全体で共有する不変の設定値（テーマ、ロケール）のみ`@Environment`を使う

### Feature分離

- Feature間の直接import禁止。Feature間通信はprotocol経由またはApp層のRouterを介す
- 各Featureはenum Routeを定義し、自身のナビゲーション先を宣言する。App層がルーティングを解決する
- FeatureがNavigationPathを直接操作しない

### データモデル互換性

- 新フィールドには必ずデフォルト値を付ける。APIレスポンスに含まれなくてもデコードが壊れないようにする
- enumには`unknown`ケースを持たせる。サーバーが新しい値を返しても壊れないようにする
- CodingKeysを明示する。プロパティ名変更とJSON key名を分離する（snake_case API対応）
- ネットワーク応答のDTO型とドメインモデルを分離する。API変更はDTO→Domain変換層で吸収する

### 設定外部化

- マジックナンバー禁止。定数はenumまたはstructで名前を付けて`AppConfig`等に集約する
- 環境ごとに変わる値（API URL、Supabase key）はxcconfig経由で注入する

### iOS 26最低ターゲット — 古い書き方を使うな

最低ターゲットはiOS 26.0。iOS 25以前のユーザーは切り捨てる。`@available`ガードは不要（全APIがiOS 26以上前提）。

**使うべきもの（iOS 26 / Swift 6.2）:**
- `@Observable` （ObservableObject / @Published は禁止）
- `NavigationStack` （NavigationView は禁止）
- Swift 6.2 concurrency（`@concurrent`、nonisolated(nonsending) デフォルト等）
- Liquid Glass マテリアル（iOS 26のデザイン言語）
- `@Previewable` マクロ（旧プレビュー構造体は禁止）
- SwiftData（Core Data は禁止。新規で使うな）
- Swift Charts（サードパーティチャートライブラリ禁止）
- `ImageRenderer`（UIGraphicsBeginImageContext 禁止）
- `AsyncImage` / Swift Concurrency ベースのネットワーキング
- `withAnimation(.spring(duration:bounce:))` 形式（旧`.spring(response:dampingFraction:)` は非推奨）

**禁止パターン:**
- Apple公式で「Deprecated」マーク付きのAPI全般
- UIKitラッパーでSwiftUI純正コンポーネントがあるもの
- `@StateObject` / `@ObservedObject` / `@EnvironmentObject` → `@State` / `@Environment` + `@Observable` で統一
- `onChange(of:perform:)` 旧シグネチャ → 新 `onChange(of:) { oldValue, newValue in }` を使う
- `AnyView` によるtype erasure → `some View` / `@ViewBuilder` で解決しろ
- iOS 26未満でしか動かないサードパーティライブラリ
- SwiftUI の `DragGesture` / `simultaneousGesture` でエッジスワイプ(サイドメニュー等)を実装するな。ScrollView の縦スクロール・水平ページングと干渉してバグの温床になる。必要なら UIKit の `UIScreenEdgePanGestureRecognizer` を `UIViewRepresentable` でブリッジしろ。ユーザーの既存操作(タブスワイプ等)を絶対に削除するな

**サードパーティライブラリ導入基準:**
- 導入前にメンテナンス状況を確認（最終更新日、issue対応頻度）。1年以上更新なしは原則禁止
- Apple純正APIで代替できるなら純正を使え

**設計判断:**
- 実装前に「この設計は2年後も成立するか」を考えろ。スケールや要件変更で破綻が見える設計は採用するな

### AsyncStream continuation と lock の組み合わせ

複数 subscriber の AsyncStream continuation を lock protected dictionary で管理する場合、**lock 内で continuation の snapshot 配列を取得し、lock 外で yield/finish を呼ぶ** pattern を厳守しろ。

**禁止パターン (nested lock deadlock):**
```swift
lock.withLock { state in
    for continuation in state.continuations.values {
        continuation.yield(value)  // yield が onTermination を同期発火 → 再 lock → deadlock
    }
}
```

**正解パターン (snapshot + lock 外 yield):**
```swift
let snapshot = lock.withLock { state -> [AsyncStream<T>.Continuation] in
    state.currentValue = value
    return Array(state.continuations.values)
}
for continuation in snapshot {
    continuation.yield(value)
}
```

**initial value 取得と継続登録の atomic 化**: `observe()` で「現在値 snapshot → continuation 登録」を別 lock scope で行うと race window ができる。1 lock scope 内で「登録 + 値取得」を atomic に実施しろ。
```swift
let initial = lock.withLock { state -> T in
    state.continuations[id] = continuation
    return state.currentValue
}
continuation.yield(initial)  // lock 外で yield
```

**stop 時の race 防止**: `continuations.removeAll()` を lock 内で実行 → lock 外で `finish()` を呼ぶ。onTermination 内の `removeValue(forKey:)` は no-op になる (既に removeAll 済)。

**由来**: T7a-2 NetworkMonitor 実装時に実 deadlock risk を発見 (2026-04-11)。`OSAllocatedUnfairLock` は iOS 16+ で **非再帰 (non-reentrant)** のため特に注意。`@unchecked Sendable` + internal lock pattern の defensive プログラミングとして必須。OfflineSyncService.observeState() / updateState() でも同 pattern 適用必須 (T7a-3)。

### Offline-first Decorator パターン (T7c, 2026-04-12)

新規 Repository を作るときは **Supabase 直接 repository** を書くだけでなく、**Offline-first Decorator** で wrap するかを判断しろ。

**何をするか:**
- `SupabaseXxxRepository` (underlying) — 既存の直接 remote 呼び出し実装
- `OfflineFirstXxxRepository` (Decorator) — underlying + `ModelContainer?` + `SyncServiceProtocol` を注入
  - **read**: remote fetch 試行 → 成功時 SD*Cache に upsert、失敗時 cache fallback
  - **write**: remote 試行 → 成功時 cache upsert + return、失敗時 `syncService.enqueue` で OfflineQueue に積む
  - **delete**: 先に SD*Cache.isDeleted = true (tombstone) → remote 試行 → 失敗時 enqueue
- `DependencyContainer` で Decorator を 5 SNS repo property に注入。preview/未注入時は underlying 直接使用 (cache 無効)

**どのタイプを Decorator 化するか:**
- **必須**: 書き込みがあるもの (Post/Like/Follow/Comment など) → data loss 回避
- **推奨**: 読み込み頻度が高くオフラインでも表示したいもの (Feed/Notification)
- **不要**: サーバー集計が必要なもの (unread_count/followers_count etc. — 直接 fetch で OK、一部 local cache で補完)

**SD*Cache (@Model) 必須フィールド:**
- `remoteId: UUID` — PK として使用、remote 確定前は local UUID
- `syncedAt: Date` — SWR 判定
- `isDeleted: Bool` — tombstone
- `updatedAtRemote: Date` — LWW conflict resolution
- `syncStatusRaw: String` — .queued / .synced / .failed 等 (SwiftData の制約で String 保持)

**lightweight migration 要件**: 全非 optional に宣言時 default 値 (SDProject 事故の教訓)。`[String]` は `Data` で保持 (migration 耐性)。

**禁止:**
- ViewModels から直接 Decorator の内部 @Model に触らない (protocol 経由で transparent)
- Decorator の `syncService` を `nil` にしない → 必ず `NoOpSyncService()` で fallback

**由来**: T7c (2026-04-12) で SNS 5 entity の offline-first infra を team-lead が一括実装。MVP scope では Decorator + FlushExecutor + SD*Cache のみで realtime subscribe は v1.1 後回し (T7d)。既存 ViewModels は変更ゼロで offline 耐性を獲得。

## Supabase / Postgres

- SwiftからSupabaseクエリを書くときも `.claude/rules/supabase-postgres.md` のルールに従え
- Repository層でクエリを書く前に、該当するreferencesファイルを読め
- 全テーブルにRLS必須。Swift側でフィルタしてるからRLS不要、は禁止
- `.from("table").select()` を書くときはインデックスの存在を確認しろ

## 多言語・テキスト長対応

- 動的テキスト（時間、日付、数値フォーマット等）は言語によって長さが大きく変わる。日本語「2時間10分」vs 英語「2h 10m」等
- 固定幅レイアウト内の動的テキストには必ず `.lineLimit(1)` と `.minimumScaleFactor(0.5)` を付けろ。改行やはみ出しを防ぐ
- テキストフォーマッタを作成・変更したら、最も長い出力パターン（例: "100時間59分"）でレイアウトが崩れないか確認しろ
- `DurationFormatter` を時間表示の唯一の手段として使え。各Viewでフォーマットロジックを書くな
- UIDatePickerのlocaleは `DurationFormatter.pickerLocale` を使え
- 設定画面の「時間の表示形式」でユーザーが切り替え可能。`UserDefaults("durationFormat")` に保存される

## パフォーマンス

- リスト系APIは必ずページネーション対応(cursor or offset+limit)
- 画像はキャッシュ+リサイズ。フルサイズ画像をそのまま表示しない
- N+1クエリ禁止。joinかバッチフェッチを使う
- フィードや集計はキャッシュパターンで。毎回計算しない
- エラーはユーザーに見せる層（View）とログに残す層（Service）を分ける
- オフライン時に壊れない設計。ネットワーク前提の処理にはローディング/エラー状態を必ず用意する
- 非推奨APIや将来削除されるAPIを使わない
