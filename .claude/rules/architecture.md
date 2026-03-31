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
- アニメーション: spring(duration 0.35, bounce 0.15-0.3)
- 機密情報はxcconfig or 環境変数。コードに埋め込まない
- 認証状態はSupabase Auth / Keychain。UserDefaultsに保存しない

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

**サードパーティライブラリ導入基準:**
- 導入前にメンテナンス状況を確認（最終更新日、issue対応頻度）。1年以上更新なしは原則禁止
- Apple純正APIで代替できるなら純正を使え

**設計判断:**
- 実装前に「この設計は2年後も成立するか」を考えろ。スケールや要件変更で破綻が見える設計は採用するな

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
