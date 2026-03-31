-- ================================================
-- Phase 0.3: daily_stats テーブル作成
-- ログ変更時に自動更新される日別統計テーブル
-- ================================================

-- 0. 依存関数: update_updated_at() が未定義の場合に作成
-- （sql/01_initial_schema.sql で定義されているが、マイグレーション単体で動作するよう保証）
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. daily_stats テーブル
CREATE TABLE IF NOT EXISTS daily_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  total_minutes INTEGER NOT NULL DEFAULT 0,
  category_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  log_count INTEGER NOT NULL DEFAULT 0,
  heartbeat_minutes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, date)
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_daily_stats_user_date
  ON daily_stats(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_stats_date
  ON daily_stats(date DESC);

-- updated_at 自動更新トリガー
CREATE TRIGGER update_daily_stats_updated_at
  BEFORE UPDATE ON daily_stats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ================================================
-- 2. RLS: 自分のデータのみ参照可能
-- ================================================
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own daily_stats"
  ON daily_stats FOR SELECT
  USING ((select auth.uid()) = user_id);

-- INSERT/UPDATE/DELETE は service_role のみ（トリガーから実行）
-- 通常ユーザーは直接書き込み不可

-- ================================================
-- 3. トリガー関数: logs 変更時に daily_stats を自動更新
-- ================================================
CREATE OR REPLACE FUNCTION refresh_daily_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_date DATE;
  v_total_minutes INTEGER;
  v_log_count INTEGER;
  v_breakdown JSONB;
BEGIN
  -- 対象のuser_idとdateを決定
  IF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;
    v_date := (OLD.started_at AT TIME ZONE 'Asia/Tokyo')::date;
  ELSIF TG_OP = 'UPDATE' THEN
    -- 日付が変わった場合は旧日付も更新
    v_user_id := NEW.user_id;
    v_date := (NEW.started_at AT TIME ZONE 'Asia/Tokyo')::date;

    IF (OLD.started_at AT TIME ZONE 'Asia/Tokyo')::date <> v_date THEN
      -- 旧日付の統計を再計算
      PERFORM refresh_daily_stats_for(OLD.user_id, (OLD.started_at AT TIME ZONE 'Asia/Tokyo')::date);
    END IF;
  ELSE
    v_user_id := NEW.user_id;
    v_date := (NEW.started_at AT TIME ZONE 'Asia/Tokyo')::date;
  END IF;

  -- 対象日の統計を再計算
  PERFORM refresh_daily_stats_for(v_user_id, v_date);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ================================================
-- 4. 実際の集計ロジック（分離して再利用可能に）
-- ================================================
CREATE OR REPLACE FUNCTION refresh_daily_stats_for(
  p_user_id UUID,
  p_date DATE
)
RETURNS VOID AS $$
DECLARE
  v_total_minutes INTEGER;
  v_log_count INTEGER;
  v_breakdown JSONB;
BEGIN
  -- 合計時間とログ件数を集計
  SELECT
    COALESCE(SUM(duration_minutes), 0),
    COUNT(*)
  INTO v_total_minutes, v_log_count
  FROM logs
  WHERE user_id = p_user_id
    AND (started_at AT TIME ZONE 'Asia/Tokyo')::date = p_date;

  -- カテゴリ別内訳を集計
  SELECT
    COALESCE(
      jsonb_object_agg(
        sub.category_name,
        jsonb_build_object(
          'minutes', sub.cat_minutes,
          'color', sub.cat_color
        )
      ),
      '{}'::jsonb
    )
  INTO v_breakdown
  FROM (
    SELECT
      COALESCE(c.name, 'その他') AS category_name,
      COALESCE(c.color, '#9CA3AF') AS cat_color,
      SUM(l.duration_minutes) AS cat_minutes
    FROM logs l
    LEFT JOIN categories c ON c.id = l.category_id
    WHERE l.user_id = p_user_id
      AND (l.started_at AT TIME ZONE 'Asia/Tokyo')::date = p_date
    GROUP BY c.name, c.color
  ) sub;

  -- UPSERT
  IF v_log_count = 0 THEN
    -- ログがなくなった場合は行を削除
    DELETE FROM daily_stats
    WHERE user_id = p_user_id AND date = p_date;
  ELSE
    INSERT INTO daily_stats (user_id, date, total_minutes, category_breakdown, log_count)
    VALUES (p_user_id, p_date, v_total_minutes, v_breakdown, v_log_count)
    ON CONFLICT (user_id, date)
    DO UPDATE SET
      total_minutes = EXCLUDED.total_minutes,
      category_breakdown = EXCLUDED.category_breakdown,
      log_count = EXCLUDED.log_count,
      updated_at = now();
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ================================================
-- 5. logs テーブルにトリガーを設定
-- ================================================
DROP TRIGGER IF EXISTS refresh_daily_stats_on_log_change ON logs;
CREATE TRIGGER refresh_daily_stats_on_log_change
  AFTER INSERT OR UPDATE OR DELETE ON logs
  FOR EACH ROW EXECUTE FUNCTION refresh_daily_stats();

-- ================================================
-- 6. 既存データのバックフィル
-- ================================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT
      user_id,
      (started_at AT TIME ZONE 'Asia/Tokyo')::date AS log_date
    FROM logs
  LOOP
    PERFORM refresh_daily_stats_for(r.user_id, r.log_date);
  END LOOP;
END;
$$;
