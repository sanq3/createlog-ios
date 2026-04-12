# CLAUDE.md

エンジニア向け作業記録・共有プラットフォーム。SwiftUI / iOS 26.0 / XcodeGen。v2.0フルリビルド中。

## プロダクト情報

- See docs/feature-roadmap.md (全機能一覧、MVP/将来の分類、設計決定ログ) ← 機能判断の正
- See docs/product-context.md (ビジョン、収益モデル、App Store規約)
- See docs/supabase-schema.md (DBスキーマ)
- See .claude/skills/supabase-postgres-best-practices/ (Postgresベストプラクティス: クエリ最適化、RLS、インデックス設計)

## ビルド

```bash
xcodegen generate
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'generic/platform=iOS Simulator' build
```

テスト:
```bash
xcodebuild -project CreateLog.xcodeproj -scheme CreateLogTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## 構成

```
CreateLog/
├── App/                          # エントリ + MainTabView (5タブ)
│   ├── DependencyContainer.swift # Composition Root (全Repository/Service集約)
│   ├── AppConfig.swift           # 定数集約 (pagination/timeout等)
│   ├── DeepLinkHandler.swift     # ディープリンクルーティング
│   ├── StoreKitManager.swift     # StoreKit 2 サブスクリプション管理
│   ├── SupabaseClient.swift      # Supabase接続 (xcconfig未設定時はダミー)
│   ├── SupabaseAuthService.swift # 認証サービス実装
│   └── Networking/               # NetworkError等
├── Core/                         # 横断的関心事
│   ├── Data/
│   │   └── Supabase/             # Repository具象実装 (全Feature共有)
│   └── Sync/                     # Offline-first 同期基盤 (T7a/T7b/T7c)
│       ├── OfflineQueueActor     # @ModelActor で SDOfflineOperation queue 排他
│       ├── OfflineSyncService    # drain loop + RetryPolicy + NetworkMonitor
│       ├── LogFlushExecutor      # T7b: Log entity の remote 同期
│       ├── SNSFlushExecutors     # T7c: Post/Like/Follow/Comment/Notification
│       ├── OfflineFirst*Repo     # T7c: SNS Decorator 5 本 (read cache + write enqueue)
│       └── NetworkMonitor        # NWPathMonitor wrapper
├── Models/                       # ドメインモデル (Foundation-only, Sendable)
│   ├── DTO/                      # Supabaseテーブル対応DTO + DTOConversions
│   ├── Repositories/             # Repository protocol定義 + NoOp実装
│   ├── Sync/                     # SD*Cache (@Model) + SyncStatus/Error/State 等
│   └── MockData.swift            # 開発用モックデータ (#if DEBUG)
├── Features/{Feature}/Views/     # 画面別View
├── Features/{Feature}/ViewModels/ # @MainActor @Observable ViewModel
├── DesignSystem/
│   ├── Tokens/                   # cl色・フォント定義
│   ├── Components/               # 再利用UIコンポーネント
│   ├── Modifiers/                # ViewModifier
│   ├── Utilities/                # HapticManager等
│   └── Extensions/               # モデル→UI変換 (Color mapping等)
└── Assets.xcassets/
CreateLogTests/              # Swift Testing (XCTest互換)
├── Models/                  # ドメインモデルのテスト
└── ...
```

## 行動原則

- **ユーザーが問題を指摘したら、以下の順序を絶対に守れ。飛ばすな:**
  1. **理解確認**: 「こう理解したが合っているか？」をユーザーに確認
  2. **原因特定**: コードを読んで根本原因を特定し報告
  3. **計画提示**: 修正計画を提示してユーザーの承認を得る
  4. **実装**: 承認後に初めてコードを書く
  - この順序を1ステップでも飛ばした場合、それは失敗。「早く直したい」は理由にならない
  - ユーザーが「はい」「やって」と言うまで Edit/Write ツールを使うな
- ユーザーの指示が曖昧なら、意図・範囲・期待する結果をヒアリングで明確にしてから動け。勝手に解釈して実装するな
- 既存の実装を正しいと仮定するな。常に疑い、問題があれば指摘して直す
- 技術的負債を「あとで直す」にするな。気づいた時点で根本から直す
- ワークアラウンドや場当たり的な修正を入れるな。原因を特定して根本解決する
- トレードオフが発生したら明示して相談する
- UIや機能に関する質問・作業の前に docs/feature-roadmap.md を必ず読め。読まずに回答するな
- プロダクトに関する決定が下されたら docs/feature-roadmap.md の設計決定ログに即追記しろ
- コード・設計・機能に変更があったら、関連するドキュメント全てを即更新しろ。対象: このCLAUDE.md、docs/配下の全ファイル、.claude/rules/配下。古い情報を残すな
