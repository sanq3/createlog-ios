-- ================================================
-- Phase 0.3: 統計クエリ用 PostgreSQL 関数群
-- すべて SECURITY INVOKER でRLSを活用
-- ================================================

-- ================================================
-- 1. get_summary_stats(p_user_id)
-- 今日/今週/今月/累計をDB側でSUM → JSON返却
-- ================================================
CREATE OR REPLACE FUNCTION get_summary_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_today DATE;
  v_week_start DATE;
  v_month_start DATE;
BEGIN
  -- auth.uid() チェック（RLS最適化形式）
  IF (select auth.uid()) IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- JST基準で日付計算
  v_today := (now() AT TIME ZONE 'Asia/Tokyo')::date;
  v_week_start := v_today - EXTRACT(DOW FROM (now() AT TIME ZONE 'Asia/Tokyo'))::integer;
  v_month_start := date_trunc('month', now() AT TIME ZONE 'Asia/Tokyo')::date;

  SELECT jsonb_build_object(
    'today', COALESCE(
      (SELECT total_minutes FROM daily_stats
       WHERE user_id = p_user_id AND date = v_today),
      0
    ),
    'this_week', COALESCE(
      (SELECT SUM(total_minutes) FROM daily_stats
       WHERE user_id = p_user_id AND date >= v_week_start),
      0
    ),
    'this_month', COALESCE(
      (SELECT SUM(total_minutes) FROM daily_stats
       WHERE user_id = p_user_id AND date >= v_month_start),
      0
    ),
    'total', COALESCE(
      (SELECT SUM(total_minutes) FROM daily_stats
       WHERE user_id = p_user_id),
      0
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp;

-- ================================================
-- 2. get_weekly_breakdown(p_user_id, p_week_offset)
-- 指定週の日別カテゴリ内訳 → JSON返却
-- ================================================
CREATE OR REPLACE FUNCTION get_weekly_breakdown(
  p_user_id UUID,
  p_week_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_week_start DATE;
  v_week_end DATE;
BEGIN
  -- auth.uid() チェック
  IF (select auth.uid()) IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- JST基準で週の範囲を計算（日曜始まり）
  v_week_start := (now() AT TIME ZONE 'Asia/Tokyo')::date
    - EXTRACT(DOW FROM (now() AT TIME ZONE 'Asia/Tokyo'))::integer
    - (p_week_offset * 7);
  v_week_end := v_week_start + 6;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'date', d.date::text,
        'day_of_week', EXTRACT(DOW FROM d.date)::integer,
        'total_minutes', COALESCE(ds.total_minutes, 0),
        'category_breakdown', COALESCE(ds.category_breakdown, '{}'::jsonb),
        'log_count', COALESCE(ds.log_count, 0)
      )
      ORDER BY d.date
    ),
    '[]'::jsonb
  ) INTO v_result
  FROM generate_series(v_week_start, v_week_end, '1 day'::interval) AS d(date)
  LEFT JOIN daily_stats ds
    ON ds.user_id = p_user_id AND ds.date = d.date::date;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp;

-- ================================================
-- 3. get_category_breakdown(p_user_id, p_period, p_week_offset)
-- カテゴリ別集計 → JSON返却
-- p_period: 'week' | 'month' | 'all'
-- ================================================
CREATE OR REPLACE FUNCTION get_category_breakdown(
  p_user_id UUID,
  p_period TEXT DEFAULT 'week',
  p_week_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_start_date DATE;
  v_end_date DATE;
BEGIN
  -- auth.uid() チェック
  IF (select auth.uid()) IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- 期間の計算
  CASE p_period
    WHEN 'week' THEN
      v_start_date := (now() AT TIME ZONE 'Asia/Tokyo')::date
        - EXTRACT(DOW FROM (now() AT TIME ZONE 'Asia/Tokyo'))::integer
        - (p_week_offset * 7);
      v_end_date := v_start_date + 6;
    WHEN 'month' THEN
      v_start_date := date_trunc('month', now() AT TIME ZONE 'Asia/Tokyo')::date;
      v_end_date := (date_trunc('month', now() AT TIME ZONE 'Asia/Tokyo') + INTERVAL '1 month' - INTERVAL '1 day')::date;
    WHEN 'all' THEN
      v_start_date := '1970-01-01'::date;
      v_end_date := '2099-12-31'::date;
    ELSE
      RAISE EXCEPTION 'Invalid period: %. Must be week, month, or all', p_period;
  END CASE;

  -- daily_stats の category_breakdown JSONB を集約
  -- 各日の category_breakdown は { "カテゴリ名": { "minutes": N, "color": "#xxx" } } 形式
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'name', cat_data.category_name,
        'minutes', cat_data.total_minutes,
        'color', cat_data.color
      )
      ORDER BY cat_data.total_minutes DESC
    ),
    '[]'::jsonb
  ) INTO v_result
  FROM (
    SELECT
      key AS category_name,
      SUM((value->>'minutes')::integer) AS total_minutes,
      -- 最新のcolorを使用
      (array_agg(value->>'color' ORDER BY ds.date DESC))[1] AS color
    FROM daily_stats ds,
      jsonb_each(ds.category_breakdown)
    WHERE ds.user_id = p_user_id
      AND ds.date >= v_start_date
      AND ds.date <= v_end_date
    GROUP BY key
  ) cat_data;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp;

-- ================================================
-- 4. get_weekly_comparison(p_user_id)
-- 今週 vs 先週の比較 → JSON返却
-- ================================================
CREATE OR REPLACE FUNCTION get_weekly_comparison(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_today DATE;
  v_day_of_week INTEGER;
  v_this_week_start DATE;
  v_last_week_start DATE;
  v_last_week_same_day DATE;
  v_this_week_minutes INTEGER;
  v_last_week_minutes INTEGER;
  v_percentage_change NUMERIC;
BEGIN
  -- auth.uid() チェック
  IF (select auth.uid()) IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- JST基準
  v_today := (now() AT TIME ZONE 'Asia/Tokyo')::date;
  v_day_of_week := EXTRACT(DOW FROM (now() AT TIME ZONE 'Asia/Tokyo'))::integer;

  -- 今週の日曜日
  v_this_week_start := v_today - v_day_of_week;
  -- 先週の日曜日
  v_last_week_start := v_this_week_start - 7;
  -- 先週の同じ曜日
  v_last_week_same_day := v_last_week_start + v_day_of_week;

  -- 今週のログ合計（日曜～今日）
  SELECT COALESCE(SUM(total_minutes), 0) INTO v_this_week_minutes
  FROM daily_stats
  WHERE user_id = p_user_id
    AND date >= v_this_week_start
    AND date <= v_today;

  -- 先週のログ合計（先週日曜～先週の同じ曜日）
  SELECT COALESCE(SUM(total_minutes), 0) INTO v_last_week_minutes
  FROM daily_stats
  WHERE user_id = p_user_id
    AND date >= v_last_week_start
    AND date <= v_last_week_same_day;

  -- 変化率の計算
  IF v_last_week_minutes = 0 AND v_this_week_minutes = 0 THEN
    v_percentage_change := NULL;
  ELSIF v_last_week_minutes = 0 THEN
    v_percentage_change := NULL; -- 先週データなし
  ELSE
    v_percentage_change := ROUND(
      ((v_this_week_minutes - v_last_week_minutes)::numeric / v_last_week_minutes) * 100
    );
  END IF;

  SELECT jsonb_build_object(
    'this_week_minutes', v_this_week_minutes,
    'last_week_minutes', v_last_week_minutes,
    'percentage_change', v_percentage_change,
    'has_last_week_data', v_last_week_minutes > 0 OR EXISTS (
      SELECT 1 FROM daily_stats
      WHERE user_id = p_user_id
        AND date >= v_last_week_start
        AND date <= v_last_week_same_day
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp;

-- ================================================
-- 5. get_user_percentile(p_user_id)
-- ユーザーの月間パーセンタイルを計算
-- ================================================
CREATE OR REPLACE FUNCTION get_user_percentile(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_month_start DATE;
  v_user_total INTEGER;
  v_total_users INTEGER;
  v_rank INTEGER;
  v_percentile NUMERIC;
BEGIN
  -- auth.uid() チェック
  IF (select auth.uid()) IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  v_month_start := date_trunc('month', now() AT TIME ZONE 'Asia/Tokyo')::date;

  -- ユーザーの今月合計
  SELECT COALESCE(SUM(total_minutes), 0) INTO v_user_total
  FROM daily_stats
  WHERE user_id = p_user_id
    AND date >= v_month_start;

  -- 全ユーザー数とランク
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE month_total >= v_user_total)
  INTO v_total_users, v_rank
  FROM (
    SELECT user_id, SUM(total_minutes) AS month_total
    FROM daily_stats
    WHERE date >= v_month_start
    GROUP BY user_id
  ) user_months;

  -- パーセンタイル計算（上位何%か）
  IF v_total_users <= 1 THEN
    v_percentile := NULL;
  ELSE
    v_percentile := ROUND((v_rank::numeric / v_total_users) * 100);
  END IF;

  SELECT jsonb_build_object(
    'user_month_total', v_user_total,
    'total_users', v_total_users,
    'rank', v_rank,
    'percentile', v_percentile
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp;
