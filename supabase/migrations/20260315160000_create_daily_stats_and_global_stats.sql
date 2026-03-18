-- Phase 2: daily_stats / global_stats テーブル作成
-- daily_stats: ユーザーごとの日次集計（事前計算済み）
-- global_stats: 全体統計（パーセンタイル含む）
--
-- NOTE: daily_stats の正本は 20260315130000_daily_stats_table.sql
-- NOTE: global_stats の正本は 20260315130001_global_stats_table.sql
-- このファイルは IF NOT EXISTS で安全だが、上記が先に適用される前提
-- スキーマが異なる（カラム名: stat_date vs date, session_count vs log_count 等）ため
-- 正本マイグレーションが先に適用済みの場合、CREATE TABLE は no-op となる

-- ============================================================
-- 1. daily_stats テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stat_date DATE NOT NULL,
  total_minutes INTEGER NOT NULL DEFAULT 0,
  session_count INTEGER NOT NULL DEFAULT 0,
  categories JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ユーザー×日付で一意
CREATE UNIQUE INDEX IF NOT EXISTS daily_stats_user_date_idx
  ON daily_stats (user_id, stat_date);

-- 日付でのフィルタリング用
CREATE INDEX IF NOT EXISTS daily_stats_stat_date_idx
  ON daily_stats (stat_date DESC);

-- RLS
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のデータのみ参照可能
CREATE POLICY "Users can view own daily_stats"
  ON daily_stats FOR SELECT
  USING ((select auth.uid()) = user_id);

-- service_role のみ書き込み可能（バッチ処理から）
CREATE POLICY "Service role can manage daily_stats"
  ON daily_stats FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================================
-- 2. global_stats テーブル
-- ============================================================
CREATE TABLE IF NOT EXISTS global_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stat_key TEXT NOT NULL,
  stat_date DATE NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  total_users INTEGER NOT NULL DEFAULT 0,
  computed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- stat_key × stat_date で一意
CREATE UNIQUE INDEX IF NOT EXISTS global_stats_key_date_idx
  ON global_stats (stat_key, stat_date);

-- 最新のグローバル統計を引くためのインデックス
CREATE INDEX IF NOT EXISTS global_stats_key_computed_idx
  ON global_stats (stat_key, computed_at DESC);

-- RLS
ALTER TABLE global_stats ENABLE ROW LEVEL SECURITY;

-- 認証ユーザーは参照可能（比較機能で使用）
CREATE POLICY "Authenticated users can view global_stats"
  ON global_stats FOR SELECT
  USING (auth.role() = 'authenticated');

-- service_role のみ書き込み可能
CREATE POLICY "Service role can manage global_stats"
  ON global_stats FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

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
      target_date AS stat_date,
      COALESCE(SUM(l.duration_minutes), 0)::INTEGER AS total_minutes,
      COUNT(*)::INTEGER AS session_count,
      COALESCE(
        jsonb_object_agg(
          COALESCE(c.name, 'その他'),
          cat_agg.cat_minutes
        ) FILTER (WHERE cat_agg.cat_minutes IS NOT NULL),
        '{}'::jsonb
      ) AS categories
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
  INSERT INTO daily_stats (user_id, stat_date, total_minutes, session_count, categories)
  SELECT user_id, stat_date, total_minutes, session_count, categories
  FROM aggregated
  ON CONFLICT (user_id, stat_date)
  DO UPDATE SET
    total_minutes = EXCLUDED.total_minutes,
    session_count = EXCLUDED.session_count,
    categories = EXCLUDED.categories,
    updated_at = timezone('utc'::text, now());

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- service_role のみ実行可能
REVOKE EXECUTE ON FUNCTION refresh_daily_stats(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_daily_stats(DATE) TO service_role;
