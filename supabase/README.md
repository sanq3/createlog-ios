# Supabase Migration Guide (2026-04-12 Phase 1 作成)

createlog-ios プロジェクトの Supabase database migration 運用手順。

## ディレクトリ構成

```
supabase/
├── baseline_audit.md                   # T1 (2026-04-10) 作成、remote DB 監査結果
├── migrations/                          # 正本: Supabase CLI 形式
│   ├── 20260404172723_fix_posts_and_create_comments.sql  # legacy (baseline 以前)
│   ├── 20260405073346_add_blocks_filter_to_comments_rls.sql  # legacy
│   ├── 20260406000000_add_handle_new_user_trigger.sql  # legacy (remote 反映済)
│   ├── 20260410152527_remote_baseline.sql  # ★ baseline, remote DB 全体 snapshot (T1)
│   ├── 20260412000000_add_replica_identity_full.sql  # T7c 先行: realtime DELETE 対応
│   └── 20260413000000_enhance_handle_new_user_trigger.sql  # T3: security hardening
└── migrations_v1_backup/                # v1.x 時代の旧 migration (参照用)
```

## 基本ルール

1. **手動 SQL 実行は禁止**。全て migration ファイル経由 (`.claude/rules/supabase-postgres.md`)
2. **service_role key** はクライアントコード・コミットに含めない (anon key のみ使用可)
3. **baseline 後の新規 migration** はすべて baseline 後の差分として作成
4. migration ファイル命名: `YYYYMMDDhhmmss_description.sql` (Supabase CLI 形式)

## 新規 migration 作成フロー

```bash
# 1. 新 migration を作成 (timestamp 自動生成)
supabase migration new <description>
# → supabase/migrations/<timestamp>_<description>.sql が生成される

# 2. SQL を記述 (alter table / create function 等)
# 3. local で試す (optional、要 Docker)
supabase db reset  # local DB を migration 全適用で reset
# または
supabase db push --dry-run  # 本番に投げる SQL を確認

# 4. production に push
supabase db push

# 5. commit (migration ファイル + 関連コード変更)
git add supabase/migrations/<file>
```

## Baseline migration の取り扱い

`20260410152527_remote_baseline.sql` は **T1 で remote DB 全体を dump した baseline**。
- サイズ: 3,483 行 (24 table + 1 view + 74 RLS policy + 29 function)
- **このファイルは local 適用されない** (既に remote に存在する定義のため)
- 新しい local 環境を構築する場合のみ reset でシードされる

### CLI 初回 setup 時 (Supabase CLI + Docker)

```bash
# 本番 DB に baseline を「適用済」としてマーク
supabase migration repair --status applied 20260410152527

# 以降は新規 migration のみ push
supabase db push
```

## Rollback 手順

Supabase は自動 rollback がない。migration で破壊的変更をする場合は必ず:
1. pre-migration backup (Supabase Dashboard → Database → Backups で snapshot 作成)
2. migration 適用
3. 失敗時は backup から restore

### ALTER TABLE の安全性

- `ADD COLUMN` with default: 基本的に safe (小さいテーブルのみ)
- `ALTER COLUMN TYPE`: lock 長時間、要 online migration tool
- `DROP COLUMN`: 即時 reversible なし、先に app deploy → 1 週間後に drop を 2 段階で
- `DROP TABLE`: 絶対に safe ではない。論理削除 (rename to `_archived_<date>`) 推奨

## Phase 1 で追加された migration

| Date | File | 内容 |
|---|---|---|
| 2026-04-10 | `20260410152527_remote_baseline.sql` | T1: remote DB baseline dump |
| 2026-04-12 | `20260412000000_add_replica_identity_full.sql` | T7c 先行: notifications/posts/comments に REPLICA IDENTITY FULL 設定 (realtime DELETE 対応) |
| 2026-04-12 | `20260413000000_enhance_handle_new_user_trigger.sql` | T3: `handle_new_user()` trigger に `SET search_path = public, pg_temp` 追加 (security hardening) |

## 未 deploy migration の確認

```bash
supabase db diff  # 本番との差分確認 (要 Docker + CLI setup)
supabase migration list  # local migration 一覧
```

## 参考

- `.claude/rules/supabase-postgres.md` — プロジェクトの Supabase ルール
- `.claude/skills/supabase-postgres-best-practices/references/` — schema/index/RLS ベストプラクティス
- `supabase/baseline_audit.md` — T1 で行った remote DB 監査結果 (テーブル/function/policy 網羅リスト)
