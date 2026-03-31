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
├── Models/                       # ドメインモデル (Foundation-only)
│   └── MockData.swift            # 開発用モックデータ
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

- 既存の実装を正しいと仮定するな。常に疑い、問題があれば指摘して直す
- 技術的負債を「あとで直す」にするな。気づいた時点で根本から直す
- ワークアラウンドや場当たり的な修正を入れるな。原因を特定して根本解決する
- トレードオフが発生したら明示して相談する
- UIや機能に関する質問・作業の前に docs/feature-roadmap.md を必ず読め。読まずに回答するな
- プロダクトに関する決定が下されたら docs/feature-roadmap.md の設計決定ログに即追記しろ
- コード・設計・機能に変更があったら、関連するドキュメント全てを即更新しろ。対象: このCLAUDE.md、docs/配下の全ファイル、.claude/rules/配下。古い情報を残すな
