-- Phase 2: daily_stats / global_stats テーブル作成
-- daily_stats: ユーザーごとの日次集計（事前計算済み）
-- global_stats: 全体統計（パーセンタイル含む）
--
-- NOTE: daily_stats の正本は 20260315130000_daily_stats_table.sql
-- NOTE: global_stats の正本は 20260315130001_global_stats_table.sql
-- このファイルは IF NOT EXISTS で安全だが、上記が先に適用される前提
-- スキーマが異なる（カラム名: date vs date, log_count vs log_count 等）ため
-- 正本マイグレーションが先に適用済みの場合、CREATE TABLE は no-op となる

-- ============================================================
-- 1. daily_stats テーブル
-- 正本: 20260315130000_daily_stats_table.sql（カラム名: date, log_count）
-- このファイルでは CREATE TABLE をスキップ
-- ============================================================

-- RLS は正本 20260315130000 で設定済み。スキップ。

-- ============================================================
-- 2. global_stats テーブル
-- 正本: 20260315130001_global_stats_table.sql（カラム名: stat_type, period_start）
-- このファイルでは CREATE TABLE をスキップ
-- ============================================================

-- RLS は正本 20260315130001 で設定済み。スキップ。

-- ============================================================
-- 3. updated_at 自動更新トリガー
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- daily_stats
DROP TRIGGER IF EXISTS update_daily_stats_updated_at ON daily_stats;
CREATE TRIGGER update_daily_stats_updated_at
  BEFORE UPDATE ON daily_stats
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- global_stats
DROP TRIGGER IF EXISTS update_global_stats_updated_at ON global_stats;
CREATE TRIGGER update_global_stats_updated_at
  BEFORE UPDATE ON global_stats
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. RPC: refresh_daily_stats(target_date DATE)
--    指定日の daily_stats を logs から再計算
-- ============================================================
CREATE OR REPLACE FUNCTION refresh_daily_stats(target_date DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  -- 指定日のログを集計して daily_stats に upsert
  WITH aggregated AS (
    SELECT
      l.user_id,
      target_date AS "date",
      COALESCE(SUM(l.duration_minutes), 0)::INTEGER AS total_minutes,
      COUNT(*)::INTEGER AS log_count,
      COALESCE(
        jsonb_object_agg(
          COALESCE(c.name, 'その他'),
          cat_agg.cat_minutes
        ) FILTER (WHERE cat_agg.cat_minutes IS NOT NULL),
        '{}'::jsonb
      ) AS category_breakdown
    FROM logs l
    LEFT JOIN categories c ON l.category_id = c.id
    LEFT JOIN LATERAL (
      SELECT SUM(l2.duration_minutes) AS cat_minutes
      FROM logs l2
      WHERE l2.user_id = l.user_id
        AND l2.category_id = l.category_id
        AND (l2.started_at AT TIME ZONE 'Asia/Tokyo')::DATE = target_date
    ) cat_agg ON true
    WHERE (l.started_at AT TIME ZONE 'Asia/Tokyo')::DATE = target_date
    GROUP BY l.user_id
  )
  INSERT INTO daily_stats (user_id, "date", total_minutes, log_count, category_breakdown)
  SELECT user_id, "date", total_minutes, log_count, category_breakdown
  FROM aggregated
  ON CONFLICT (user_id, "date")
  DO UPDATE SET
    total_minutes = EXCLUDED.total_minutes,
    log_count = EXCLUDED.log_count,
    category_breakdown = EXCLUDED.category_breakdown,
    updated_at = timezone('utc'::text, now());

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- service_role のみ実行可能
REVOKE EXECUTE ON FUNCTION refresh_daily_stats(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_daily_stats(DATE) TO service_role;
