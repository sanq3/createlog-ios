---
description: SQL・マイグレーション・Supabaseスキーマ作業時のPostgresベストプラクティス適用
globs: ["**/*.sql", "**/supabase/**", "**/migrations/**", "docs/supabase-schema.md"]
---

# Supabase / Postgres ルール

このルールが発動したら、作業内容に応じて `.claude/skills/supabase-postgres-best-practices/references/` から該当ファイルを読んでから作業しろ。

## 必須チェック

### テーブル作成・スキーマ変更時
読むべきリファレンス:
- `schema-primary-keys.md` — PK設計
- `schema-data-types.md` — 型選択
- `schema-constraints.md` — 制約
- `schema-foreign-key-indexes.md` — FK索引
- `schema-lowercase-identifiers.md` — 命名規則
- `security-rls-basics.md` — RLS有効化

### クエリ作成・最適化時
読むべきリファレンス:
- `query-missing-indexes.md` — インデックス漏れ
- `query-composite-indexes.md` — 複合インデックス
- `query-partial-indexes.md` — 部分インデックス
- `data-n-plus-one.md` — N+1防止
- `data-pagination.md` — ページネーション

### RLS・認証関連
読むべきリファレンス:
- `security-rls-basics.md` — RLS基本
- `security-rls-performance.md` — RLSパフォーマンス
- `security-privileges.md` — 権限設計

### 接続・運用
読むべきリファレンス:
- `conn-pooling.md` — コネクションプーリング
- `conn-limits.md` — 接続数制限
- `conn-idle-timeout.md` — アイドルタイムアウト

## 原則

- 全テーブルにRLSを有効化しろ。例外なし
- WHERE/JOINカラムにインデックスがあるか確認しろ
- N+1クエリを書くな。joinかバッチフェッチを使え
- リスト取得は必ずページネーション付きにしろ
- 識別子は全て小文字スネークケースにしろ

## Supabase操作ルール

- Supabaseの操作（テーブル確認、マイグレーション、Auth設定、API設定等）はダッシュボードではなく `supabase` CLIから行え
- プロジェクト ref は `supabase link` 済、`supabase projects list` で確認可能 (コミットにハードコードしない)
- service_roleキーをクライアントコード・コミットに含めるな。anon keyのみ使用可
- スキーマ変更はマイグレーションファイル経由で行え。手動SQL実行禁止
