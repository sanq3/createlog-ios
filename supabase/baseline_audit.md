# Supabase Baseline Audit (Phase 1 / T1)

- 実施日: 2026-04-11
- 担当: swift-implementer (createlog-dev チーム)
- 対象 project ref: `aeycoojfugzzuvrpfjhj`
- 対象スキーマ: `public`
- 基準ファイル: `supabase/migrations/20260410152527_remote_baseline.sql` (3,483 行)
- DB は読み取りのみ (`pg_dump --schema-only`)、一切の変更を加えていない

## 取得方法 (備忘)

`supabase db pull --linked` は migration history 不一致でブロック (local にある `20260406000000_add_handle_new_user_trigger.sql` が remote 未適用のため)。
`supabase db dump --linked` は Docker Desktop 依存で失敗。代替として `supabase db dump --linked --schema public --dry-run` で生成される `pg_dump` スクリプトを取り出し、ローカルの `/opt/homebrew/opt/libpq/bin/pg_dump` (v17.2) で直接実行した。CLI が一時的な `cli_login_postgres` ロールのパスワードを発行するため、パスワード管理は不要。

---

## 1. 実テーブル一覧 (remote public schema)

計 **24 テーブル + 1 view** が remote に存在。全テーブルで RLS 有効化済 (`ENABLE ROW LEVEL SECURITY` × 24)、`CREATE POLICY` は 74 本。

| # | テーブル | columns | 備考 |
|---|---|---|---|
| 1 | `profiles` | 31 | v1 基盤 + SNS (`handle`, `nickname`, `followers_count`, `posts_count`, `status_*` 等) の拡張版 |
| 2 | `categories` | 10 | v1 基盤そのまま |
| 3 | `logs` | 11 | v1 基盤そのまま。`started_at` インデックスあり |
| 4 | `monthly_revenues` | 8 | v1 基盤 + 後続 unify |
| 5 | `subscriptions` | 12 | v1 基盤 |
| 6 | `apps` | 16 | Phase 5 ショーケース |
| 7 | `app_tags` | 4 | Phase 5 |
| 8 | `review_requests` | 13 | Phase 5 |
| 9 | `reviews` | 13 | Phase 5 |
| 10 | `reviewer_scores` | 11 | Phase 5 |
| 11 | `posts` | 15 | SNS Phase 1.1 + 20260318 statement consolidation |
| 12 | `follows` | 4 | SNS |
| 13 | `likes` | 4 | SNS |
| 14 | `blocks` | 4 | SNS |
| 15 | `comments` | 8 | 20260318 / 20260404 で最新化 |
| 16 | `notifications` | 9 | SNS + 20260318 notification-types 拡張 |
| 17 | `hashtags` | 4 | SNS hashtag |
| 18 | `post_hashtags` | 3 | SNS hashtag 中間 |
| 19 | `mentions` | 5 | SNS mention |
| 20 | `reports` | 9 | UGC 通報 (App Store 1.2b) |
| 21 | `daily_stats` | 9 | 統計事前計算 |
| 22 | `global_stats` | 8 | 全体パーセンタイル |
| 23 | `heartbeats` | 11 | 自動トラッキング |
| 24 | `api_keys` | 10 | 自動トラッキング用 |
| v1 | `trending_hashtags` (view) | – | hashtags 集計 view |

関数も 29 本 (`handle_new_user`, `set_updated_at`, `get_weekly_comparison`, `refresh_global_stats`, `update_*_counts` 等) 定義済み。

---

## 2. Migration history 差分

`supabase migration list --linked` 結果:

| 状態 | version | ファイル |
|---|---|---|
| local ✅ / remote ✅ | `20260404172723` | `fix_posts_and_create_comments.sql` |
| local ✅ / remote ✅ | `20260405073346` | `add_blocks_filter_to_comments_rls.sql` |
| local ✅ / remote ❌ | `20260406000000` | `add_handle_new_user_trigger.sql` |

### 2-a. migrations/ (3 ファイル) 内容サマリ

| ファイル | 内容 |
|---|---|
| `20260404172723_fix_posts_and_create_comments.sql` | `posts` の column 正規化 (`likes_count/reposts_count/comments_count/media_urls/visibility`)、`comments` テーブル新規作成 + RLS + `update_post_comments_count` trigger、`notifications.type` CHECK 拡張、`profiles.handle` 追加 |
| `20260405073346_add_blocks_filter_to_comments_rls.sql` | `comments_select` policy に blocks 相互フィルタを追加 (blocks テーブル存在時のみ適用) |
| `20260406000000_add_handle_new_user_trigger.sql` | `public.handle_new_user()` を `SECURITY DEFINER + search_path` 固定で再定義し `on_auth_user_created` trigger を再作成、過去ユーザーの `profiles` backfill |

### 2-b. remote にあるが `migrations/` に無いもの

`migrations/` は 20260404 以降の差分のみ保持している。**20260404 より前に適用された全 DDL (初期 24 テーブル・74 policy・29 function・各種 trigger・storage bucket) は `migrations/` には存在しない**。これらは `migrations_v1_backup/` に原本があるが、リンクされていないので `supabase db push` からは参照されない。

新しく作られた `20260410152527_remote_baseline.sql` は、これらの「失われた過去」を 1 ファイルで丸ごと表現するベースラインとして機能する。

### 2-c. 20260406000000 が remote 未適用の意味

- v1_backup 時代のトリガーが生きているので動作に影響はなさそうだが、`SECURITY DEFINER + search_path` 固定の強化版は未適用。
- Phase 1 で push する前に、baseline と本 migration の関係を整理して `migration repair` で何を applied とするか決める必要がある (後述 T3)。

---

## 3. `migrations_v1_backup/` の用途

35 ファイル。v1 (Expo/React Native 時代) に使われていた sequential migration をそのまま保存した **歴史資料**。v2 iOS リビルドで `migrations/` をクリーンリセットするため、履歴消失を避けて backup ディレクトリに退避した。remote DB にはこれらの DDL の成果物がほぼそのまま残っているため、消さずに参照可能な状態で保持する価値がある。

### 時系列サマリ

| 時期 | 内容 |
|---|---|
| 2025-10-01 | `init_base_tables`: profiles / categories / logs / monthly_revenues / subscriptions / comparisons_cache の 6 基盤 + `handle_new_user` trigger + デフォルトカテゴリ + avatars bucket |
| 2025-10-09 | `enable_rls_policies`: 基盤 6 テーブルに RLS ポリシー |
| 2025-11-21 | `create_comparisons_cache` (後に 2026-03-15 で deprecate) |
| 2025-12-01 | avatars bucket / comparisons_cache のロックダウン、48h 編集制限を RLS から削除 (アプリ層へ移管) |
| 2026-03-15 (Phase 0.1〜4) | `security_rls_optimization`、`handle/nickname` 追加、`daily_stats` / `global_stats` / `stats_functions`、`monthly_revenues` unify、`logs.started_at` index、SNS (posts / follows / likes / blocks / notifications / profiles columns)、comparisons_cache deprecate、heartbeats、api_keys、apps、app_tags、review_requests、reviews、reviewer_scores |
| 2026-03-16 | `sns_reposts`、`sns_hashtags`、`profile_status`、`status_auto_clear` |
| 2026-03-17 | `reports_table` (UGC 通報) |
| 2026-03-18 | `fix_posts_table_consolidation` (20260315150000 と 20260316100000 の競合を解消)、`create_comments_table`、`expand_notification_types_and_mentions` |

### 重要な発見

1. **`comparisons_cache` は deprecate 済**。`migrations_v1_backup/20260315160001_deprecate_comparisons_cache.sql` で削除され、remote に存在しない。一方 `docs/supabase-schema.md` にはまだ記載されている → ドキュメント更新要 (T3 範囲)。
2. **`posts` は 2 回定義されていた** (`20260315150000_sns_posts_table.sql` と `20260316100000_sns_reposts.sql`)。`20260318082108_fix_posts_table_consolidation.sql` で統合され、さらに `20260404172723_fix_posts_and_create_comments.sql` で column 正規化された。現在の remote はこの最終形。
3. **`profiles` が 31 column**と巨大。v1 基盤の 16 列 + `handle / nickname / bio / followers_count / following_count / posts_count / status_* / status_updated_at / banner_url` 等の SNS / status 拡張が積み重なった結果。

---

## 4. 既存 9 Repository × remote テーブル 整合性

| Repository | 参照テーブル | remote 存在 |
|---|---|---|
| `SupabaseProfileRepository` | `profiles` | ✅ |
| `SupabaseCategoryRepository` | `categories` | ✅ |
| `SupabaseLogRepository` | `logs` | ✅ |
| `SupabaseStatsRepository` | `logs` | ✅ |
| `SupabaseAppRepository` | `apps` | ✅ |
| `SupabaseSNSRepository` | `posts`, `follows`, `likes`, `comments` | ✅ 4/4 |
| `SupabaseSearchRepository` | `profiles`, `posts`, `apps` | ✅ 3/3 |
| `SupabaseNotificationRepository` | `notifications` | ✅ |
| `SupabaseUGCRepository` | `reports`, `blocks` | ✅ 2/2 |

**全 9 Repository が参照する 11 テーブルは remote に存在**。rename 不要、DTO + 既存実装はそのまま生かせる (承認済 B1)。

ただし、以下のテーブルは remote に存在するが **Repository 側未対応** (後続タスクで Repository 追加 or ViewModel 拡張):

- `monthly_revenues` (Profile / Stats 拡張で使う予定)
- `subscriptions` (StoreKit との同期)
- `app_tags` / `review_requests` / `reviews` / `reviewer_scores` (Phase 5 Review 交換)
- `hashtags` / `post_hashtags` / `mentions` (SNS hashtag/mention)
- `daily_stats` / `global_stats` (パーセンタイル / 比較)
- `heartbeats` / `api_keys` (自動トラッキング)

---

## 5. `docs/supabase-schema.md` との差分

`docs/supabase-schema.md` は 11 テーブル (profiles / categories / logs / monthly_revenues / subscriptions / comparisons_cache / apps / app_tags / review_requests / reviews / reviewer_scores) を記載しているが、実 remote は 24 テーブル + 1 view。

### ドキュメント側の問題点 (T3 で修正すべき)

1. **comparisons_cache を削除**: remote にも無い (deprecate 済)。
2. **欠落テーブルの追記**: SNS 系 (posts / follows / likes / comments / blocks / notifications / hashtags / post_hashtags / mentions / reports)、stats 系 (daily_stats / global_stats)、auto-tracking 系 (heartbeats / api_keys)。
3. **profiles の column 拡張を反映**: v1 16 列 → v2 31 列、SNS / status 系追加分を明記。
4. **trending_hashtags view の追加**。

---

## 6. 次の T3 (v2 MVP 10 テーブル完全化) への見立て

チームリードの前提では **v2 MVP 10 テーブル**だが、実 remote は既に 24 テーブル存在しており、「足りない」ではなく「過剰に持っている」状態。T3 で着手すべきは "不足の追加" ではなく "整理と宣言的管理への移行"。

### 推奨アクション

1. **baseline migration を履歴登録する** (`supabase migration repair --status applied 20260410152527`)。これで `migrations/` = remote と宣言できる。あわせて `20260406000000` をどう扱うか決める:
   - (a) 先に remote へ `supabase db push` で適用してから baseline を作り直す
   - (b) baseline に既に `handle_new_user` の v2 版を含むので `20260406000000` を削除 (baseline 優先)
   - どちらが user 意図に合うかチームリードに判断を仰ぐ (baseline dump には既に `handle_new_user` の古い版が入っているため、厳密には (a) を推奨)
2. **v2 MVP に実際に必要なテーブルを確定**する。候補:
   - 確実に使う (Phase 1-2): `profiles`, `categories`, `logs`, `subscriptions`, `monthly_revenues`, `apps`, `posts`, `follows`, `likes`, `comments`, `notifications`, `blocks`, `reports`
   - 判断必要: `daily_stats` / `global_stats` (オフライン-first では iOS 側で計算するため不要かも)、`heartbeats` / `api_keys` (自動トラッキング機能の v2 採用可否)、`review_requests` / `reviews` / `reviewer_scores` / `app_tags` (Phase 5 の範囲決定次第)、`hashtags` / `post_hashtags` / `mentions` (v1 MVP に hashtag 入れるか)
3. **不要テーブル / 過剰 column の整理**: v2 で使わないものは `DROP TABLE` migration を書いて remote から除去する。ただし **削除はユーザー確認必須** (破壊的)。本タスクでは一切触らない。
4. **docs/supabase-schema.md を上記実テーブル確定後に全面書き換え**。
5. **RLS / index の改善余地**: 74 policy あるが、`select auth.uid() as uid` パターンが徹底されており `security_rls_optimization.sql` の成果が反映済 = インデックスは十分そう。baseline から index 一覧を後で精査する (現状確認済、問題なし)。

### ブロッカー / リスク

- `supabase db push` する場合 remote に影響が出るため、必ず user 承認が必要。
- Docker Desktop が起動していない状態では `supabase db dump` / `supabase db pull` が使えない (今回は libpq 直叩きで回避)。T3 以降で `db push` を行う際も libpq 経由のワークアラウンドが必要になる可能性あり (Docker 起動か、CLI バージョンアップで回避できるか要確認)。
- v2.67.1 → v2.84.2 の CLI アップデート推奨通知あり。

---

## 7. 受け入れ条件チェック

- [x] `supabase/migrations/20260410152527_remote_baseline.sql` 作成 (3,483 行)
- [x] `supabase/baseline_audit.md` 作成
- [x] 実テーブル一覧 (24 + 1 view、column 数付き)
- [x] `migrations/` にあるが remote にないもの (20260406000000)
- [x] remote にあるが `migrations/` にないもの (baseline 以前の全 DDL)
- [x] `migrations_v1_backup/` の用途と歴史
- [x] 既存 9 Repository の参照テーブル健在性確認
- [x] T3 向けの見立て
- [x] ビルド影響なし (Swift コード無変更)
