-- ================================================
-- Phase 0.3: global_stats テーブル作成
-- 全体統計・パーセンタイル計算用
-- ================================================

-- 1. global_stats テーブル
CREATE TABLE IF NOT EXISTS global_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stat_type TEXT NOT NULL,
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  user_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(stat_type, period_start)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_global_stats_type_period
  ON global_stats(stat_type, period_start DESC);

-- updated_at 自動更新トリガー
CREATE TRIGGER update_global_stats_updated_at
  BEFORE UPDATE ON global_stats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ================================================
-- 2. RLS: SELECT は認証ユーザー全員、書き込みは service_role のみ
-- ================================================
ALTER TABLE global_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view global_stats"
  ON global_stats FOR SELECT
  USING (auth.role() = 'authenticated');

-- INSERT/UPDATE/DELETE ポリシーは作成しない
-- → service_role のみが書き込み可能

-- ================================================
-- 3. バッチ関数: 全体統計を更新
-- SECURITY DEFINER で service_role から呼び出される想定
-- ================================================
CREATE OR REPLACE FUNCTION refresh_global_stats()
RETURNS VOID AS $$
DECLARE
  v_now TIMESTAMPTZ := now();
  v_today_start TIMESTAMPTZ;
  v_week_start TIMESTAMPTZ;
  v_month_start TIMESTAMPTZ;
  v_data JSONB;
  v_user_count INTEGER;
BEGIN
  -- 期間の計算（JST基準）
  v_today_start := date_trunc('day', v_now AT TIME ZONE 'Asia/Tokyo') AT TIME ZONE 'Asia/Tokyo';
  -- 週の開始（日曜日）
  v_week_start := v_today_start - (EXTRACT(DOW FROM v_now AT TIME ZONE 'Asia/Tokyo') * INTERVAL '1 day');
  v_month_start := date_trunc('month', v_now AT TIME ZONE 'Asia/Tokyo') AT TIME ZONE 'Asia/Tokyo';

  -- アクティブユーザー数
  SELECT COUNT(DISTINCT user_id) INTO v_user_count
  FROM daily_stats
  WHERE date >= (v_month_start AT TIME ZONE 'Asia/Tokyo')::date;

  -- 全体統計を計算
  SELECT jsonb_build_object(
    'avg_today_minutes', COALESCE(
      (SELECT AVG(total_minutes)::integer
       FROM daily_stats
       WHERE date = (v_now AT TIME ZONE 'Asia/Tokyo')::date),
      0
    ),
    'avg_daily_minutes', COALESCE(
      (SELECT AVG(daily_avg)::integer
       FROM (
         SELECT user_id, AVG(total_minutes) AS daily_avg
         FROM daily_stats
         WHERE date >= (v_month_start AT TIME ZONE 'Asia/Tokyo')::date
         GROUP BY user_id
       ) user_avgs),
      0
    ),
    'avg_week_minutes', COALESCE(
      (SELECT AVG(week_total)::integer
       FROM (
         SELECT user_id, SUM(total_minutes) AS week_total
         FROM daily_stats
         WHERE date >= (v_week_start AT TIME ZONE 'Asia/Tokyo')::date
         GROUP BY user_id
       ) user_weeks),
      0
    ),
    'avg_month_minutes', COALESCE(
      (SELECT AVG(month_total)::integer
       FROM (
         SELECT user_id, SUM(total_minutes) AS month_total
         FROM daily_stats
         WHERE date >= (v_month_start AT TIME ZONE 'Asia/Tokyo')::date
         GROUP BY user_id
       ) user_months),
      0
    ),
    'total_users', v_user_count
  ) INTO v_data;

  -- UPSERT: hourly スナップショット
  INSERT INTO global_stats (stat_type, period_start, period_end, data, user_count)
  VALUES (
    'hourly_snapshot',
    date_trunc('hour', v_now),
    date_trunc('hour', v_now) + INTERVAL '1 hour',
    v_data,
    v_user_count
  )
  ON CONFLICT (stat_type, period_start)
  DO UPDATE SET
    data = EXCLUDED.data,
    user_count = EXCLUDED.user_count,
    updated_at = now();

  -- パーセンタイル計算用データ
  INSERT INTO global_stats (stat_type, period_start, period_end, data, user_count)
  VALUES (
    'percentiles',
    date_trunc('hour', v_now),
    date_trunc('hour', v_now) + INTERVAL '1 hour',
    (
      SELECT jsonb_build_object(
        'p25', COALESCE(percentile_disc(0.25) WITHIN GROUP (ORDER BY month_total), 0),
        'p50', COALESCE(percentile_disc(0.50) WITHIN GROUP (ORDER BY month_total), 0),
        'p75', COALESCE(percentile_disc(0.75) WITHIN GROUP (ORDER BY month_total), 0),
        'p90', COALESCE(percentile_disc(0.90) WITHIN GROUP (ORDER BY month_total), 0)
      )
      FROM (
        SELECT user_id, SUM(total_minutes) AS month_total
        FROM daily_stats
        WHERE date >= (v_month_start AT TIME ZONE 'Asia/Tokyo')::date
        GROUP BY user_id
      ) user_months
    ),
    v_user_count
  )
  ON CONFLICT (stat_type, period_start)
  DO UPDATE SET
    data = EXCLUDED.data,
    user_count = EXCLUDED.user_count,
    updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ================================================
-- 4. 初回データ投入（既存データからグローバル統計を生成）
-- ================================================
SELECT refresh_global_stats();
