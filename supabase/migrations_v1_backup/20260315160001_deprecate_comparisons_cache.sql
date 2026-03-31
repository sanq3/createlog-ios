-- Phase 2: comparisons_cache テーブル廃止
-- global_stats に統合完了のため、comparisons_cache を削除する。
--
-- ロールバック手順:
--   20251121_create_comparisons_cache.sql を再適用すればテーブルが復元される。
--   ただしデータは失われるため、get-stats-comparison Edge Function が
--   自動的にキャッシュを再構築する（旧バージョンの場合）。

-- 関連するポリシーを先に削除
DROP POLICY IF EXISTS "Service role can read comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can insert comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can update comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "Service role can delete comparisons cache" ON comparisons_cache;
DROP POLICY IF EXISTS "All authenticated users can view cache" ON comparisons_cache;

-- テーブルを削除
DROP TABLE IF EXISTS comparisons_cache;
