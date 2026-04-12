

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."clear_stale_profile_status"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE profiles
  SET
    current_status = NULL,
    status_type = NULL,
    status_project = NULL,
    status_started_at = NULL,
    status_updated_at = NULL
  WHERE status_type IS NOT NULL
    AND status_updated_at < NOW() - INTERVAL '10 minutes';
END;
$$;


ALTER FUNCTION "public"."clear_stale_profile_status"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."clear_stale_profile_status"() IS 'Clears profile status when status_updated_at is older than 10 minutes. Called by aggregate-heartbeats Edge Function or pg_cron.';



CREATE OR REPLACE FUNCTION "public"."decrement_hashtag_post_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE hashtags
    SET post_count = GREATEST(post_count - 1, 0)
  WHERE id = OLD.hashtag_id;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."decrement_hashtag_post_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."extract_and_link_hashtags"("p_post_id" "uuid", "p_content" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  tag TEXT;
  tag_id UUID;
BEGIN
  -- 既存のリンクを削除（UPDATE 時に再計算するため）
  DELETE FROM post_hashtags WHERE post_id = p_post_id;

  -- #ハッシュタグ パターンを抽出（英数字・アンダースコア・日本語対応）
  FOR tag IN
    SELECT DISTINCT lower(m[1])
    FROM regexp_matches(p_content, '#([a-zA-Z0-9_\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]+)', 'g') AS m
  LOOP
    -- hashtags テーブルに UPSERT
    INSERT INTO hashtags (name)
      VALUES (tag)
      ON CONFLICT (name) DO NOTHING
      RETURNING id INTO tag_id;

    -- RETURNING が NULL の場合（既存）は SELECT で取得
    IF tag_id IS NULL THEN
      SELECT h.id INTO tag_id FROM hashtags h WHERE h.name = tag;
    END IF;

    -- ジャンクションテーブルにリンク
    INSERT INTO post_hashtags (post_id, hashtag_id)
      VALUES (p_post_id, tag_id)
      ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."extract_and_link_hashtags"("p_post_id" "uuid", "p_content" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."extract_and_link_mentions"("p_post_id" "uuid", "p_comment_id" "uuid", "p_content" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  mention_handle text;
  mentioned_user_id uuid;
  source_user_id uuid;
BEGIN
  -- メンション元のユーザーIDを取得
  IF p_post_id IS NOT NULL THEN
    SELECT user_id INTO source_user_id FROM posts WHERE id = p_post_id;
    -- 既存のメンションを削除（UPDATE 時に再計算）
    DELETE FROM mentions WHERE post_id = p_post_id;
  ELSIF p_comment_id IS NOT NULL THEN
    SELECT user_id INTO source_user_id FROM comments WHERE id = p_comment_id;
    DELETE FROM mentions WHERE comment_id = p_comment_id;
  END IF;

  -- @handle パターンを抽出
  FOR mention_handle IN
    SELECT DISTINCT lower(m[1])
    FROM regexp_matches(p_content, '@([a-zA-Z0-9_]+)', 'g') AS m
  LOOP
    -- handle からユーザーIDを取得
    SELECT id INTO mentioned_user_id
    FROM profiles
    WHERE handle = mention_handle;

    -- ユーザーが存在し、自分自身でない場合のみ
    IF mentioned_user_id IS NOT NULL AND mentioned_user_id != source_user_id THEN
      -- mentions テーブルに追加
      INSERT INTO mentions (post_id, comment_id, user_id)
        VALUES (p_post_id, p_comment_id, mentioned_user_id)
        ON CONFLICT DO NOTHING;

      -- 通知を作成
      INSERT INTO notifications (user_id, actor_id, type, post_id, comment_id)
        VALUES (mentioned_user_id, source_user_id, 'mention', p_post_id, p_comment_id);
    END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."extract_and_link_mentions"("p_post_id" "uuid", "p_comment_id" "uuid", "p_content" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_category_breakdown"("p_user_id" "uuid", "p_period" "text" DEFAULT 'week'::"text", "p_week_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_category_breakdown"("p_user_id" "uuid", "p_period" "text", "p_week_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_or_create_user_categories"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  -- セキュリティチェック: 呼び出し元ユーザーと p_user_id が一致するか検証
  -- service_role（auth.uid() IS NULL）は許可、通常ユーザーは本人のみ許可
  IF (select auth.uid()) IS NOT NULL AND p_user_id IS DISTINCT FROM (select auth.uid()) THEN
    RAISE EXCEPTION 'unauthorized: p_user_id does not match auth.uid()';
  END IF;

  -- ユーザー用のカテゴリが存在しない場合、デフォルトからコピー
  IF NOT EXISTS (SELECT 1 FROM categories WHERE user_id = p_user_id) THEN
    INSERT INTO public.categories (user_id, name, color, icon, is_active, is_default, display_order)
    SELECT
      p_user_id,
      name,
      color,
      icon,
      is_active,
      false, -- ユーザーカテゴリは is_default=false
      display_order
    FROM public.categories
    WHERE is_default = true;
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_or_create_user_categories"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_summary_stats"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_summary_stats"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_percentile"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_user_percentile"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_weekly_breakdown"("p_user_id" "uuid", "p_week_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_weekly_breakdown"("p_user_id" "uuid", "p_week_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_weekly_comparison"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_weekly_comparison"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_hashtag_post_count"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE hashtags
    SET post_count = post_count + 1
  WHERE id = NEW.hashtag_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."increment_hashtag_post_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_daily_stats"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."refresh_daily_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_daily_stats"("target_date" "date" DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."refresh_daily_stats"("target_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_daily_stats_for"("p_user_id" "uuid", "p_date" "date") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."refresh_daily_stats_for"("p_user_id" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_global_stats"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER FUNCTION "public"."refresh_global_stats"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_follows_on_block"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- 双方向のフォロー関係を解除
  DELETE FROM follows
  WHERE (follower_id = NEW.blocker_id AND following_id = NEW.blocked_id)
     OR (follower_id = NEW.blocked_id AND following_id = NEW.blocker_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."remove_follows_on_block"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_extract_comment_mentions"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.content IS NOT NULL THEN
    PERFORM extract_and_link_mentions(NULL, NEW.id, NEW.content);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_extract_comment_mentions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_extract_hashtags"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM extract_and_link_hashtags(NEW.id, NEW.content);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_extract_hashtags"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_extract_post_mentions"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.content IS NOT NULL THEN
    PERFORM extract_and_link_mentions(NEW.id, NULL, NEW.content);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_extract_post_mentions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_app_rating_on_review"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- 新規公開または公開ステータスへの変更時
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status <> 'published') THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      )
    WHERE id = NEW.app_id;
  END IF;

  -- 公開から非公開への変更時
  IF TG_OP = 'UPDATE' AND OLD.status = 'published' AND NEW.status <> 'published' THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      )
    WHERE id = NEW.app_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_app_rating_on_review"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_app_rating_on_review_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF OLD.status = 'published' THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = OLD.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = OLD.app_id AND status = 'published'
      )
    WHERE id = OLD.app_id;
  END IF;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."update_app_rating_on_review_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_apps_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_apps_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_comments_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  -- 論理削除
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = false AND NEW.is_deleted = true THEN
    UPDATE posts SET comments_count = GREATEST(comments_count - 1, 0)
    WHERE id = NEW.post_id;
  END IF;
  -- 論理削除の復元
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = true AND NEW.is_deleted = false THEN
    UPDATE posts SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_comments_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_comments_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_comments_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_follow_counts"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- フォローする側の following_count +1
    UPDATE profiles SET following_count = following_count + 1
    WHERE id = NEW.follower_id;
    -- フォローされる側の followers_count +1
    UPDATE profiles SET followers_count = followers_count + 1
    WHERE id = NEW.following_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- フォローする側の following_count -1
    UPDATE profiles SET following_count = GREATEST(following_count - 1, 0)
    WHERE id = OLD.follower_id;
    -- フォローされる側の followers_count -1
    UPDATE profiles SET followers_count = GREATEST(followers_count - 1, 0)
    WHERE id = OLD.following_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_follow_counts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_post_comments_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_post_comments_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_post_likes_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = GREATEST(likes_count - 1, 0)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_post_likes_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_posts_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE profiles SET posts_count = posts_count + 1
    WHERE id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE profiles SET posts_count = GREATEST(posts_count - 1, 0)
    WHERE id = OLD.user_id;
    RETURN OLD;
  END IF;
  -- 論理削除の場合（is_deleted が false → true）
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = false AND NEW.is_deleted = true THEN
    UPDATE profiles SET posts_count = GREATEST(posts_count - 1, 0)
    WHERE id = NEW.user_id;
  END IF;
  -- 論理削除の復元（is_deleted が true → false）
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = true AND NEW.is_deleted = false THEN
    UPDATE profiles SET posts_count = posts_count + 1
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_posts_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_posts_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_posts_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_repost_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.repost_of_id IS NOT NULL THEN
    UPDATE posts
      SET repost_count = repost_count + 1
    WHERE id = NEW.repost_of_id;
  END IF;

  IF TG_OP = 'DELETE' AND OLD.repost_of_id IS NOT NULL THEN
    UPDATE posts
      SET repost_count = GREATEST(repost_count - 1, 0)
    WHERE id = OLD.repost_of_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION "public"."update_repost_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_review_requests_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_review_requests_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_reviewer_scores_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_reviewer_scores_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_reviews_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_reviews_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."api_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" DEFAULT 'Default'::"text" NOT NULL,
    "key_hash" "text" NOT NULL,
    "key_prefix" "text" NOT NULL,
    "last_used_at" timestamp with time zone,
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."api_keys" OWNER TO "postgres";


COMMENT ON TABLE "public"."api_keys" IS 'エディタ拡張・デスクトップアプリの認証用APIキー';



COMMENT ON COLUMN "public"."api_keys"."key_hash" IS 'APIキーのSHA-256ハッシュ。平文は保存しない';



COMMENT ON COLUMN "public"."api_keys"."key_prefix" IS 'APIキーの先頭8文字。ユーザーがキーを識別するため';



CREATE TABLE IF NOT EXISTS "public"."app_tags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "app_id" "uuid" NOT NULL,
    "tag" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."app_tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."apps" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "icon_url" "text",
    "screenshots" "jsonb" DEFAULT '[]'::"jsonb",
    "platform" "text" DEFAULT 'other'::"text" NOT NULL,
    "app_url" "text",
    "store_url" "text",
    "github_url" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "category" "text",
    "avg_rating" numeric(3,2) DEFAULT 0,
    "review_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "apps_platform_check" CHECK (("platform" = ANY (ARRAY['ios'::"text", 'android'::"text", 'web'::"text", 'other'::"text"]))),
    CONSTRAINT "apps_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'published'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."apps" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."blocks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "blocker_id" "uuid" NOT NULL,
    "blocked_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_no_self_block" CHECK (("blocker_id" <> "blocked_id"))
);


ALTER TABLE "public"."blocks" OWNER TO "postgres";


COMMENT ON TABLE "public"."blocks" IS 'ユーザーブロック';



COMMENT ON COLUMN "public"."blocks"."blocker_id" IS 'ブロックした側のユーザーID';



COMMENT ON COLUMN "public"."blocks"."blocked_id" IS 'ブロックされた側のユーザーID';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "color" "text" NOT NULL,
    "icon" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "parent_comment_id" "uuid",
    "content" "text" NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "comments_content_check" CHECK (("char_length"("content") <= 1000))
);


ALTER TABLE "public"."comments" OWNER TO "postgres";


COMMENT ON TABLE "public"."comments" IS '投稿へのコメント';



COMMENT ON COLUMN "public"."comments"."post_id" IS '対象の投稿ID';



COMMENT ON COLUMN "public"."comments"."user_id" IS 'コメント投稿者のユーザーID';



COMMENT ON COLUMN "public"."comments"."parent_comment_id" IS '返信先コメントID（NULLならトップレベルコメント）';



COMMENT ON COLUMN "public"."comments"."content" IS 'コメント本文（最大1000文字）';



COMMENT ON COLUMN "public"."comments"."is_deleted" IS '論理削除フラグ';



CREATE TABLE IF NOT EXISTS "public"."daily_stats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "total_minutes" integer DEFAULT 0 NOT NULL,
    "category_breakdown" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "log_count" integer DEFAULT 0 NOT NULL,
    "heartbeat_minutes" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."daily_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."follows" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "follower_id" "uuid" NOT NULL,
    "following_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "chk_no_self_follow" CHECK (("follower_id" <> "following_id"))
);


ALTER TABLE "public"."follows" OWNER TO "postgres";


COMMENT ON TABLE "public"."follows" IS 'フォロー関係（Twitter型）';



COMMENT ON COLUMN "public"."follows"."follower_id" IS 'フォローする側のユーザーID';



COMMENT ON COLUMN "public"."follows"."following_id" IS 'フォローされる側のユーザーID';



CREATE TABLE IF NOT EXISTS "public"."global_stats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stat_type" "text" NOT NULL,
    "period_start" timestamp with time zone NOT NULL,
    "period_end" timestamp with time zone NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "user_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."global_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."hashtags" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "post_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "hashtag_name_lowercase" CHECK (("name" = "lower"("name")))
);


ALTER TABLE "public"."hashtags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."heartbeats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "source" "text" NOT NULL,
    "project_name" "text" DEFAULT ''::"text" NOT NULL,
    "file_path" "text" DEFAULT ''::"text" NOT NULL,
    "language" "text" DEFAULT ''::"text" NOT NULL,
    "category_id" "uuid",
    "timestamp" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_processed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "heartbeats_source_check" CHECK (("source" = ANY (ARRAY['vscode'::"text", 'claude_code'::"text", 'codex'::"text", 'desktop'::"text"])))
);


ALTER TABLE "public"."heartbeats" OWNER TO "postgres";


COMMENT ON TABLE "public"."heartbeats" IS 'エディタ・デスクトップアプリからのheartbeatイベント';



COMMENT ON COLUMN "public"."heartbeats"."source" IS 'イベント送信元 (vscode, claude_code, codex, desktop)';



COMMENT ON COLUMN "public"."heartbeats"."is_processed" IS 'aggregate-heartbeats で集約済みか';



CREATE TABLE IF NOT EXISTS "public"."likes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "post_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."likes" OWNER TO "postgres";


COMMENT ON TABLE "public"."likes" IS '投稿へのいいね';



COMMENT ON COLUMN "public"."likes"."user_id" IS 'いいねしたユーザーID';



COMMENT ON COLUMN "public"."likes"."post_id" IS '対象の投稿ID';



CREATE TABLE IF NOT EXISTS "public"."logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" DEFAULT 'その他'::"text" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "ended_at" timestamp with time zone NOT NULL,
    "duration_minutes" integer NOT NULL,
    "memo" "text",
    "is_timer" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "logs_duration_minutes_check" CHECK (("duration_minutes" >= 0))
);


ALTER TABLE "public"."logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mentions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid",
    "comment_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "mentions_source_check" CHECK (((("post_id" IS NOT NULL) AND ("comment_id" IS NULL)) OR (("post_id" IS NULL) AND ("comment_id" IS NOT NULL))))
);


ALTER TABLE "public"."mentions" OWNER TO "postgres";


COMMENT ON TABLE "public"."mentions" IS 'メンション（@ユーザー）';



COMMENT ON COLUMN "public"."mentions"."post_id" IS 'メンション元の投稿ID';



COMMENT ON COLUMN "public"."mentions"."comment_id" IS 'メンション元のコメントID';



COMMENT ON COLUMN "public"."mentions"."user_id" IS 'メンションされたユーザーID';



CREATE TABLE IF NOT EXISTS "public"."monthly_revenues" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "year" integer NOT NULL,
    "month" integer NOT NULL,
    "revenue" numeric(10,2) DEFAULT 0 NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "monthly_revenues_month_check" CHECK ((("month" >= 1) AND ("month" <= 12))),
    CONSTRAINT "monthly_revenues_year_check" CHECK ((("year" >= 2020) AND ("year" <= 2100)))
);


ALTER TABLE "public"."monthly_revenues" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "actor_id" "uuid",
    "type" "text" NOT NULL,
    "post_id" "uuid",
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "comment_id" "uuid",
    CONSTRAINT "notifications_type_check" CHECK (("type" = ANY (ARRAY['like'::"text", 'follow'::"text", 'comment'::"text", 'mention'::"text", 'repost'::"text", 'quote'::"text", 'system'::"text"])))
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."notifications" IS 'アプリ内通知';



COMMENT ON COLUMN "public"."notifications"."user_id" IS '通知の受信者';



COMMENT ON COLUMN "public"."notifications"."actor_id" IS '通知のトリガーとなったユーザー（NULLはシステム通知）';



COMMENT ON COLUMN "public"."notifications"."type" IS '通知タイプ: follow / like / comment / mention / repost / quote / review_request / review_completed / milestone';



COMMENT ON COLUMN "public"."notifications"."post_id" IS '関連する投稿（いいね通知等で使用）';



COMMENT ON COLUMN "public"."notifications"."data" IS '追加データ（マイルストーン詳細等）';



COMMENT ON COLUMN "public"."notifications"."is_read" IS '既読フラグ';



COMMENT ON COLUMN "public"."notifications"."comment_id" IS '関連するコメントID（コメント/メンション通知で使用）';



CREATE TABLE IF NOT EXISTS "public"."post_hashtags" (
    "post_id" "uuid" NOT NULL,
    "hashtag_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."post_hashtags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "log_id" "uuid",
    "content" "text" NOT NULL,
    "visibility" "text" DEFAULT 'public'::"text" NOT NULL,
    "likes_count" integer DEFAULT 0 NOT NULL,
    "is_deleted" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "repost_of_id" "uuid",
    "quote_of_id" "uuid",
    "repost_count" integer DEFAULT 0 NOT NULL,
    "comments_count" integer DEFAULT 0 NOT NULL,
    "reposts_count" integer DEFAULT 0 NOT NULL,
    "media_urls" "jsonb" DEFAULT '[]'::"jsonb",
    CONSTRAINT "posts_comments_count_check" CHECK (("comments_count" >= 0)),
    CONSTRAINT "posts_content_check" CHECK (("char_length"("content") <= 2000)),
    CONSTRAINT "posts_content_repost_check" CHECK ((("repost_of_id" IS NOT NULL) OR (("content" IS NOT NULL) AND ("content" <> ''::"text")))),
    CONSTRAINT "posts_likes_count_check" CHECK (("likes_count" >= 0)),
    CONSTRAINT "posts_repost_count_check" CHECK (("repost_count" >= 0)),
    CONSTRAINT "posts_repost_or_quote" CHECK ((NOT (("repost_of_id" IS NOT NULL) AND ("quote_of_id" IS NOT NULL)))),
    CONSTRAINT "posts_visibility_check" CHECK (("visibility" = ANY (ARRAY['public'::"text", 'followers_only'::"text", 'private'::"text"])))
);


ALTER TABLE "public"."posts" OWNER TO "postgres";


COMMENT ON TABLE "public"."posts" IS 'SNS投稿';



COMMENT ON COLUMN "public"."posts"."user_id" IS '投稿者のユーザーID';



COMMENT ON COLUMN "public"."posts"."log_id" IS '紐付け作業ログ（NULL許可）';



COMMENT ON COLUMN "public"."posts"."content" IS '投稿本文（最大2000文字）';



COMMENT ON COLUMN "public"."posts"."visibility" IS '公開範囲: public / followers_only / private';



COMMENT ON COLUMN "public"."posts"."likes_count" IS 'いいね数（非正規化カウンタ）';



COMMENT ON COLUMN "public"."posts"."is_deleted" IS '論理削除フラグ';



COMMENT ON COLUMN "public"."posts"."repost_of_id" IS 'リポスト元の投稿ID（NULLならオリジナル投稿）';



COMMENT ON COLUMN "public"."posts"."quote_of_id" IS '引用元の投稿ID（NULLなら引用なし）';



COMMENT ON COLUMN "public"."posts"."repost_count" IS 'リポスト数（非正規化カウンタ）';



COMMENT ON COLUMN "public"."posts"."comments_count" IS 'コメント数（非正規化カウンタ）';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "display_name" "text",
    "avatar_url" "text",
    "role" "text" DEFAULT 'developer'::"text" NOT NULL,
    "age_group" "text",
    "gender" "text",
    "occupation" "text",
    "work_type" "text",
    "income_status" "text",
    "experience_years" "text",
    "bio" "text",
    "timezone" "text" DEFAULT 'Asia/Tokyo'::"text" NOT NULL,
    "notification_enabled" boolean DEFAULT true NOT NULL,
    "onboarding_completed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "handle" "text",
    "nickname" "text",
    "visibility" "text" DEFAULT 'public'::"text" NOT NULL,
    "followers_count" integer DEFAULT 0 NOT NULL,
    "following_count" integer DEFAULT 0 NOT NULL,
    "posts_count" integer DEFAULT 0 NOT NULL,
    "github_url" "text",
    "x_url" "text",
    "website_url" "text",
    "current_status" "text",
    "status_type" "text",
    "status_project" "text",
    "status_started_at" timestamp with time zone,
    "status_updated_at" timestamp with time zone,
    CONSTRAINT "profiles_age_group_check" CHECK (("age_group" = ANY (ARRAY['10代'::"text", '20代'::"text", '30代'::"text", '40代'::"text", '50代以上'::"text"]))),
    CONSTRAINT "profiles_experience_years_check" CHECK (("experience_years" = ANY (ARRAY['under_3_months'::"text", 'three_to_six_months'::"text", 'six_to_twelve_months'::"text", 'one_to_two_years'::"text", 'two_to_three_years'::"text", 'three_to_four_years'::"text", 'four_to_five_years'::"text", 'over_five_years'::"text"]))),
    CONSTRAINT "profiles_followers_count_check" CHECK (("followers_count" >= 0)),
    CONSTRAINT "profiles_following_count_check" CHECK (("following_count" >= 0)),
    CONSTRAINT "profiles_gender_check" CHECK (("gender" = ANY (ARRAY['男性'::"text", '女性'::"text", 'その他'::"text", '回答しない'::"text"]))),
    CONSTRAINT "profiles_income_status_check" CHECK (("income_status" = ANY (ARRAY['no_income'::"text", 'under_10k'::"text", '10k_to_50k'::"text", '50k_to_100k'::"text", '100k_to_200k'::"text", '200k_to_300k'::"text", '300k_to_500k'::"text", 'over_500k'::"text"]))),
    CONSTRAINT "profiles_occupation_check" CHECK (("occupation" = ANY (ARRAY['会社員'::"text", 'フリーランス'::"text", '学生'::"text", 'その他'::"text"]))),
    CONSTRAINT "profiles_posts_count_check" CHECK (("posts_count" >= 0)),
    CONSTRAINT "profiles_status_type_check" CHECK ((("status_type" IS NULL) OR ("status_type" = ANY (ARRAY['timer'::"text", 'auto_tracking'::"text", 'manual'::"text"])))),
    CONSTRAINT "profiles_visibility_check" CHECK (("visibility" = ANY (ARRAY['public'::"text", 'followers_only'::"text", 'private'::"text"]))),
    CONSTRAINT "profiles_work_type_check" CHECK (("work_type" = ANY (ARRAY['副業'::"text", '本業'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."visibility" IS 'プロフィール公開範囲: public / followers_only / private';



COMMENT ON COLUMN "public"."profiles"."followers_count" IS 'フォロワー数（非正規化）';



COMMENT ON COLUMN "public"."profiles"."following_count" IS 'フォロー数（非正規化）';



COMMENT ON COLUMN "public"."profiles"."posts_count" IS '投稿数（非正規化）';



COMMENT ON COLUMN "public"."profiles"."github_url" IS 'GitHub プロフィールURL';



COMMENT ON COLUMN "public"."profiles"."x_url" IS 'X (Twitter) プロフィールURL';



COMMENT ON COLUMN "public"."profiles"."website_url" IS '個人サイトURL';



COMMENT ON COLUMN "public"."profiles"."current_status" IS 'Human-readable status text, e.g. "React Nativeを開発中"';



COMMENT ON COLUMN "public"."profiles"."status_type" IS 'Activity source: timer | auto_tracking | manual';



COMMENT ON COLUMN "public"."profiles"."status_project" IS 'Project name from heartbeat or timer category';



COMMENT ON COLUMN "public"."profiles"."status_started_at" IS 'When the current activity session started';



COMMENT ON COLUMN "public"."profiles"."status_updated_at" IS 'Last heartbeat or status refresh timestamp';



CREATE TABLE IF NOT EXISTS "public"."reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "target_type" "text" NOT NULL,
    "target_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "description" "text",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "reports_reason_check" CHECK (("reason" = ANY (ARRAY['spam'::"text", 'harassment'::"text", 'inappropriate'::"text", 'misinformation'::"text", 'other'::"text"]))),
    CONSTRAINT "reports_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'reviewed'::"text", 'resolved'::"text", 'dismissed'::"text"]))),
    CONSTRAINT "reports_target_type_check" CHECK (("target_type" = ANY (ARRAY['post'::"text", 'user'::"text", 'app'::"text", 'review'::"text"])))
);


ALTER TABLE "public"."reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."review_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "app_id" "uuid" NOT NULL,
    "requester_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "review_points" "text"[],
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "matched_at" timestamp with time zone,
    "deadline" timestamp with time zone,
    "max_reviewers" integer DEFAULT 1 NOT NULL,
    "current_reviewers" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "review_requests_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'matched'::"text", 'in_progress'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."review_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviewer_scores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "total_reviews" integer DEFAULT 0 NOT NULL,
    "completed_reviews" integer DEFAULT 0 NOT NULL,
    "avg_review_quality" numeric(3,2) DEFAULT 0,
    "reliability_score" numeric(5,2) DEFAULT 100.00 NOT NULL,
    "penalties_count" integer DEFAULT 0 NOT NULL,
    "last_penalty_at" timestamp with time zone,
    "streak_completed" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."reviewer_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "review_request_id" "uuid" NOT NULL,
    "app_id" "uuid" NOT NULL,
    "reviewer_id" "uuid" NOT NULL,
    "rating" integer NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "pros" "text"[],
    "cons" "text"[],
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "submitted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reviews_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
    CONSTRAINT "reviews_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'submitted'::"text", 'published'::"text"])))
);


ALTER TABLE "public"."reviews" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'inactive'::"text" NOT NULL,
    "plan_type" "text" DEFAULT 'free'::"text" NOT NULL,
    "provider" "text",
    "provider_subscription_id" "text",
    "provider_customer_id" "text",
    "current_period_start" timestamp with time zone,
    "current_period_end" timestamp with time zone,
    "cancel_at_period_end" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "subscriptions_plan_type_check" CHECK (("plan_type" = ANY (ARRAY['free'::"text", 'premium'::"text"]))),
    CONSTRAINT "subscriptions_provider_check" CHECK (("provider" = ANY (ARRAY['stripe'::"text", 'app_store'::"text"]))),
    CONSTRAINT "subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'canceled'::"text", 'past_due'::"text"])))
);


ALTER TABLE "public"."subscriptions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."trending_hashtags" AS
 SELECT "h"."id",
    "h"."name",
    "h"."post_count",
    "count"("ph"."post_id") AS "recent_count"
   FROM ("public"."hashtags" "h"
     JOIN "public"."post_hashtags" "ph" ON (("ph"."hashtag_id" = "h"."id")))
  WHERE ("ph"."created_at" > ("now"() - '24:00:00'::interval))
  GROUP BY "h"."id", "h"."name", "h"."post_count"
  ORDER BY ("count"("ph"."post_id")) DESC, "h"."post_count" DESC
 LIMIT 20;


ALTER VIEW "public"."trending_hashtags" OWNER TO "postgres";


ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_tags"
    ADD CONSTRAINT "app_tags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."apps"
    ADD CONSTRAINT "apps_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_name_key" UNIQUE ("user_id", "name");



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_stats"
    ADD CONSTRAINT "daily_stats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_stats"
    ADD CONSTRAINT "daily_stats_user_id_date_key" UNIQUE ("user_id", "date");



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_stats"
    ADD CONSTRAINT "global_stats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."global_stats"
    ADD CONSTRAINT "global_stats_stat_type_period_start_key" UNIQUE ("stat_type", "period_start");



ALTER TABLE ONLY "public"."hashtags"
    ADD CONSTRAINT "hashtags_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."hashtags"
    ADD CONSTRAINT "hashtags_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."heartbeats"
    ADD CONSTRAINT "heartbeats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mentions"
    ADD CONSTRAINT "mentions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."monthly_revenues"
    ADD CONSTRAINT "monthly_revenues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."monthly_revenues"
    ADD CONSTRAINT "monthly_revenues_user_id_year_month_key" UNIQUE ("user_id", "year", "month");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_hashtags"
    ADD CONSTRAINT "post_hashtags_pkey" PRIMARY KEY ("post_id", "hashtag_id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."review_requests"
    ADD CONSTRAINT "review_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviewer_scores"
    ADD CONSTRAINT "reviewer_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "uq_blocks_pair" UNIQUE ("blocker_id", "blocked_id");



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "uq_follows_pair" UNIQUE ("follower_id", "following_id");



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "uq_likes_user_post" UNIQUE ("user_id", "post_id");



CREATE INDEX "idx_api_keys_key_hash" ON "public"."api_keys" USING "btree" ("key_hash") WHERE ("is_active" = true);



CREATE UNIQUE INDEX "idx_api_keys_key_prefix_user" ON "public"."api_keys" USING "btree" ("user_id", "key_prefix");



CREATE INDEX "idx_api_keys_user_id" ON "public"."api_keys" USING "btree" ("user_id");



CREATE INDEX "idx_app_tags_app_id" ON "public"."app_tags" USING "btree" ("app_id");



CREATE INDEX "idx_app_tags_tag" ON "public"."app_tags" USING "btree" ("tag");



CREATE UNIQUE INDEX "idx_app_tags_unique" ON "public"."app_tags" USING "btree" ("app_id", "tag");



CREATE INDEX "idx_apps_avg_rating" ON "public"."apps" USING "btree" ("avg_rating" DESC);



CREATE INDEX "idx_apps_category" ON "public"."apps" USING "btree" ("category");



CREATE INDEX "idx_apps_created_at" ON "public"."apps" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_apps_platform" ON "public"."apps" USING "btree" ("platform");



CREATE INDEX "idx_apps_status" ON "public"."apps" USING "btree" ("status");



CREATE INDEX "idx_apps_user_id" ON "public"."apps" USING "btree" ("user_id");



CREATE INDEX "idx_blocks_blocked" ON "public"."blocks" USING "btree" ("blocked_id");



CREATE INDEX "idx_blocks_blocker" ON "public"."blocks" USING "btree" ("blocker_id");



CREATE INDEX "idx_categories_default" ON "public"."categories" USING "btree" ("is_default");



CREATE INDEX "idx_categories_user_active" ON "public"."categories" USING "btree" ("user_id", "is_active");



CREATE INDEX "idx_comments_created_at" ON "public"."comments" USING "btree" ("post_id", "created_at");



CREATE INDEX "idx_comments_parent" ON "public"."comments" USING "btree" ("parent_comment_id") WHERE ("parent_comment_id" IS NOT NULL);



CREATE INDEX "idx_comments_post_created" ON "public"."comments" USING "btree" ("post_id", "created_at") WHERE ("is_deleted" = false);



CREATE INDEX "idx_comments_post_id" ON "public"."comments" USING "btree" ("post_id");



CREATE INDEX "idx_comments_user_created" ON "public"."comments" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_comments_user_id" ON "public"."comments" USING "btree" ("user_id");



CREATE INDEX "idx_daily_stats_date" ON "public"."daily_stats" USING "btree" ("date" DESC);



CREATE INDEX "idx_daily_stats_user_date" ON "public"."daily_stats" USING "btree" ("user_id", "date" DESC);



CREATE INDEX "idx_follows_follower" ON "public"."follows" USING "btree" ("follower_id", "created_at" DESC);



CREATE INDEX "idx_follows_following" ON "public"."follows" USING "btree" ("following_id", "created_at" DESC);



CREATE INDEX "idx_global_stats_type_period" ON "public"."global_stats" USING "btree" ("stat_type", "period_start" DESC);



CREATE INDEX "idx_hashtags_name" ON "public"."hashtags" USING "btree" ("name");



CREATE INDEX "idx_hashtags_post_count" ON "public"."hashtags" USING "btree" ("post_count" DESC);



CREATE INDEX "idx_heartbeats_created_at" ON "public"."heartbeats" USING "btree" ("created_at");



CREATE INDEX "idx_heartbeats_unprocessed" ON "public"."heartbeats" USING "btree" ("user_id", "is_processed", "timestamp") WHERE ("is_processed" = false);



CREATE INDEX "idx_heartbeats_user_timestamp" ON "public"."heartbeats" USING "btree" ("user_id", "timestamp" DESC);



CREATE INDEX "idx_likes_post" ON "public"."likes" USING "btree" ("post_id", "created_at" DESC);



CREATE INDEX "idx_likes_user" ON "public"."likes" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_logs_started_at" ON "public"."logs" USING "btree" ("started_at" DESC);



CREATE INDEX "idx_logs_user_category" ON "public"."logs" USING "btree" ("user_id", "category_id");



CREATE INDEX "idx_logs_user_created" ON "public"."logs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_logs_user_started" ON "public"."logs" USING "btree" ("user_id", "started_at" DESC);



CREATE INDEX "idx_mentions_comment" ON "public"."mentions" USING "btree" ("comment_id") WHERE ("comment_id" IS NOT NULL);



CREATE INDEX "idx_mentions_post" ON "public"."mentions" USING "btree" ("post_id") WHERE ("post_id" IS NOT NULL);



CREATE UNIQUE INDEX "idx_mentions_unique_comment" ON "public"."mentions" USING "btree" ("comment_id", "user_id") WHERE ("comment_id" IS NOT NULL);



CREATE UNIQUE INDEX "idx_mentions_unique_post" ON "public"."mentions" USING "btree" ("post_id", "user_id") WHERE ("post_id" IS NOT NULL);



CREATE INDEX "idx_mentions_user" ON "public"."mentions" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_notifications_user_created" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_notifications_user_unread" ON "public"."notifications" USING "btree" ("user_id", "is_read", "created_at" DESC) WHERE ("is_read" = false);



CREATE INDEX "idx_post_hashtags_created" ON "public"."post_hashtags" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_post_hashtags_hashtag" ON "public"."post_hashtags" USING "btree" ("hashtag_id");



CREATE INDEX "idx_post_hashtags_post" ON "public"."post_hashtags" USING "btree" ("post_id");



CREATE INDEX "idx_posts_feed" ON "public"."posts" USING "btree" ("visibility", "is_deleted", "created_at" DESC) WHERE ("is_deleted" = false);



CREATE INDEX "idx_posts_quote_of_id" ON "public"."posts" USING "btree" ("quote_of_id") WHERE ("quote_of_id" IS NOT NULL);



CREATE INDEX "idx_posts_repost_of_id" ON "public"."posts" USING "btree" ("repost_of_id") WHERE ("repost_of_id" IS NOT NULL);



CREATE UNIQUE INDEX "idx_posts_unique_repost" ON "public"."posts" USING "btree" ("user_id", "repost_of_id") WHERE ("repost_of_id" IS NOT NULL);



CREATE INDEX "idx_posts_user_created" ON "public"."posts" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_profiles_created" ON "public"."profiles" USING "btree" ("created_at");



CREATE UNIQUE INDEX "idx_profiles_handle" ON "public"."profiles" USING "btree" ("handle") WHERE ("handle" IS NOT NULL);



CREATE INDEX "idx_profiles_role_work" ON "public"."profiles" USING "btree" ("role", "work_type");



CREATE INDEX "idx_profiles_status_type" ON "public"."profiles" USING "btree" ("status_type") WHERE ("status_type" IS NOT NULL);



CREATE INDEX "idx_profiles_visibility" ON "public"."profiles" USING "btree" ("visibility") WHERE ("visibility" = 'public'::"text");



CREATE INDEX "idx_reports_reporter" ON "public"."reports" USING "btree" ("reporter_id");



CREATE INDEX "idx_reports_status" ON "public"."reports" USING "btree" ("status") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_reports_target" ON "public"."reports" USING "btree" ("target_type", "target_id");



CREATE UNIQUE INDEX "idx_reports_unique_per_reporter" ON "public"."reports" USING "btree" ("reporter_id", "target_type", "target_id");



CREATE INDEX "idx_revenues_user_period" ON "public"."monthly_revenues" USING "btree" ("user_id", "year" DESC, "month" DESC);



CREATE INDEX "idx_review_requests_app_id" ON "public"."review_requests" USING "btree" ("app_id");



CREATE INDEX "idx_review_requests_created_at" ON "public"."review_requests" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_review_requests_requester_id" ON "public"."review_requests" USING "btree" ("requester_id");



CREATE INDEX "idx_review_requests_status" ON "public"."review_requests" USING "btree" ("status");



CREATE INDEX "idx_reviewer_scores_reliability" ON "public"."reviewer_scores" USING "btree" ("reliability_score" DESC);



CREATE UNIQUE INDEX "idx_reviewer_scores_user_id" ON "public"."reviewer_scores" USING "btree" ("user_id");



CREATE INDEX "idx_reviews_app_id" ON "public"."reviews" USING "btree" ("app_id");



CREATE INDEX "idx_reviews_rating" ON "public"."reviews" USING "btree" ("rating");



CREATE INDEX "idx_reviews_review_request_id" ON "public"."reviews" USING "btree" ("review_request_id");



CREATE INDEX "idx_reviews_reviewer_id" ON "public"."reviews" USING "btree" ("reviewer_id");



CREATE INDEX "idx_reviews_status" ON "public"."reviews" USING "btree" ("status");



CREATE UNIQUE INDEX "idx_reviews_unique_per_request" ON "public"."reviews" USING "btree" ("review_request_id", "reviewer_id");



CREATE INDEX "idx_subscriptions_provider" ON "public"."subscriptions" USING "btree" ("provider", "provider_subscription_id");



CREATE INDEX "idx_subscriptions_status" ON "public"."subscriptions" USING "btree" ("status", "plan_type");



CREATE OR REPLACE TRIGGER "refresh_daily_stats_on_log_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."logs" FOR EACH ROW EXECUTE FUNCTION "public"."refresh_daily_stats"();



CREATE OR REPLACE TRIGGER "set_reports_updated_at" BEFORE UPDATE ON "public"."reports" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_categories_updated_at" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_comments_count" AFTER INSERT OR DELETE OR UPDATE OF "is_deleted" ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_comments_count"();



CREATE OR REPLACE TRIGGER "trg_comments_extract_mentions" AFTER INSERT OR UPDATE OF "content" ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_extract_comment_mentions"();



CREATE OR REPLACE TRIGGER "trg_comments_updated_at" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_comments_updated_at"();



CREATE OR REPLACE TRIGGER "trg_decrement_hashtag_count" AFTER DELETE ON "public"."post_hashtags" FOR EACH ROW EXECUTE FUNCTION "public"."decrement_hashtag_post_count"();



CREATE OR REPLACE TRIGGER "trg_follow_counts" AFTER INSERT OR DELETE ON "public"."follows" FOR EACH ROW EXECUTE FUNCTION "public"."update_follow_counts"();



CREATE OR REPLACE TRIGGER "trg_increment_hashtag_count" AFTER INSERT ON "public"."post_hashtags" FOR EACH ROW EXECUTE FUNCTION "public"."increment_hashtag_post_count"();



CREATE OR REPLACE TRIGGER "trg_likes_count" AFTER INSERT OR DELETE ON "public"."likes" FOR EACH ROW EXECUTE FUNCTION "public"."update_post_likes_count"();



CREATE OR REPLACE TRIGGER "trg_logs_updated_at" BEFORE UPDATE ON "public"."logs" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_posts_count" AFTER INSERT OR DELETE OR UPDATE OF "is_deleted" ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."update_posts_count"();



CREATE OR REPLACE TRIGGER "trg_posts_extract_hashtags" AFTER INSERT OR UPDATE OF "content" ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_extract_hashtags"();



CREATE OR REPLACE TRIGGER "trg_posts_extract_mentions" AFTER INSERT OR UPDATE OF "content" ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_extract_post_mentions"();



CREATE OR REPLACE TRIGGER "trg_posts_updated_at" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."update_posts_updated_at"();



CREATE OR REPLACE TRIGGER "trg_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_remove_follows_on_block" AFTER INSERT ON "public"."blocks" FOR EACH ROW EXECUTE FUNCTION "public"."remove_follows_on_block"();



CREATE OR REPLACE TRIGGER "trg_repost_count_delete" AFTER DELETE ON "public"."posts" FOR EACH ROW WHEN (("old"."repost_of_id" IS NOT NULL)) EXECUTE FUNCTION "public"."update_repost_count"();



CREATE OR REPLACE TRIGGER "trg_repost_count_insert" AFTER INSERT ON "public"."posts" FOR EACH ROW WHEN (("new"."repost_of_id" IS NOT NULL)) EXECUTE FUNCTION "public"."update_repost_count"();



CREATE OR REPLACE TRIGGER "trg_revenues_updated_at" BEFORE UPDATE ON "public"."monthly_revenues" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_subscriptions_updated_at" BEFORE UPDATE ON "public"."subscriptions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_update_comments_count" AFTER INSERT OR DELETE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."update_post_comments_count"();



CREATE OR REPLACE TRIGGER "trigger_apps_updated_at" BEFORE UPDATE ON "public"."apps" FOR EACH ROW EXECUTE FUNCTION "public"."update_apps_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_review_requests_updated_at" BEFORE UPDATE ON "public"."review_requests" FOR EACH ROW EXECUTE FUNCTION "public"."update_review_requests_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_reviewer_scores_updated_at" BEFORE UPDATE ON "public"."reviewer_scores" FOR EACH ROW EXECUTE FUNCTION "public"."update_reviewer_scores_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_reviews_updated_at" BEFORE UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_reviews_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_update_app_rating" AFTER INSERT OR UPDATE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_app_rating_on_review"();



CREATE OR REPLACE TRIGGER "trigger_update_app_rating_on_delete" AFTER DELETE ON "public"."reviews" FOR EACH ROW EXECUTE FUNCTION "public"."update_app_rating_on_review_delete"();



CREATE OR REPLACE TRIGGER "update_api_keys_updated_at" BEFORE UPDATE ON "public"."api_keys" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at"();



CREATE OR REPLACE TRIGGER "update_daily_stats_updated_at" BEFORE UPDATE ON "public"."daily_stats" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_global_stats_updated_at" BEFORE UPDATE ON "public"."global_stats" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."api_keys"
    ADD CONSTRAINT "api_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."app_tags"
    ADD CONSTRAINT "app_tags_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "public"."apps"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."apps"
    ADD CONSTRAINT "apps_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."blocks"
    ADD CONSTRAINT "blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_stats"
    ADD CONSTRAINT "daily_stats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_follower_id_fkey" FOREIGN KEY ("follower_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."follows"
    ADD CONSTRAINT "follows_following_id_fkey" FOREIGN KEY ("following_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."heartbeats"
    ADD CONSTRAINT "heartbeats_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."heartbeats"
    ADD CONSTRAINT "heartbeats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."likes"
    ADD CONSTRAINT "likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mentions"
    ADD CONSTRAINT "mentions_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mentions"
    ADD CONSTRAINT "mentions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mentions"
    ADD CONSTRAINT "mentions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."monthly_revenues"
    ADD CONSTRAINT "monthly_revenues_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_hashtags"
    ADD CONSTRAINT "post_hashtags_hashtag_id_fkey" FOREIGN KEY ("hashtag_id") REFERENCES "public"."hashtags"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_hashtags"
    ADD CONSTRAINT "post_hashtags_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_log_id_fkey" FOREIGN KEY ("log_id") REFERENCES "public"."logs"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_quote_of_id_fkey" FOREIGN KEY ("quote_of_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_repost_of_id_fkey" FOREIGN KEY ("repost_of_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reports"
    ADD CONSTRAINT "reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."review_requests"
    ADD CONSTRAINT "review_requests_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "public"."apps"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."review_requests"
    ADD CONSTRAINT "review_requests_requester_id_fkey" FOREIGN KEY ("requester_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviewer_scores"
    ADD CONSTRAINT "reviewer_scores_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "public"."apps"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_review_request_id_fkey" FOREIGN KEY ("review_request_id") REFERENCES "public"."review_requests"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reviews"
    ADD CONSTRAINT "reviews_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscriptions"
    ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "App tags are viewable when app is visible" ON "public"."app_tags" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."apps"
  WHERE (("apps"."id" = "app_tags"."app_id") AND (("apps"."status" = 'published'::"text") OR ("apps"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Authenticated users can view global_stats" ON "public"."global_stats" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view hashtags" ON "public"."hashtags" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Authenticated users can view post_hashtags" ON "public"."post_hashtags" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Only service role can update reviewer scores" ON "public"."reviewer_scores" FOR UPDATE USING (false);



CREATE POLICY "Open review requests are viewable by authenticated users" ON "public"."review_requests" FOR SELECT USING ((("status" = ANY (ARRAY['open'::"text", 'matched'::"text", 'in_progress'::"text", 'completed'::"text"])) OR ("requester_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Published apps are viewable by authenticated users" ON "public"."apps" FOR SELECT USING ((("status" = 'published'::"text") OR ("user_id" = ( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Published reviews are viewable, own reviews always viewable" ON "public"."reviews" FOR SELECT USING ((("status" = 'published'::"text") OR ("reviewer_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM "public"."review_requests"
  WHERE (("review_requests"."id" = "reviews"."review_request_id") AND ("review_requests"."requester_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "Reviewer scores are viewable by authenticated users" ON "public"."reviewer_scores" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") IS NOT NULL));



CREATE POLICY "Users can create reports" ON "public"."reports" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "reporter_id"));



CREATE POLICY "Users can delete own api_keys" ON "public"."api_keys" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete own apps" ON "public"."apps" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can delete own draft reviews" ON "public"."reviews" FOR DELETE USING ((("reviewer_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'draft'::"text")));



CREATE POLICY "Users can delete own heartbeats" ON "public"."heartbeats" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can delete own open review requests" ON "public"."review_requests" FOR DELETE USING ((("requester_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = 'open'::"text")));



CREATE POLICY "Users can delete own post hashtags" ON "public"."post_hashtags" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."posts" "p"
  WHERE (("p"."id" = "post_hashtags"."post_id") AND ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can delete tags for own apps" ON "public"."app_tags" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."apps"
  WHERE (("apps"."id" = "app_tags"."app_id") AND ("apps"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can insert own api_keys" ON "public"."api_keys" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert own apps" ON "public"."apps" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can insert own heartbeats" ON "public"."heartbeats" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can insert own post hashtags" ON "public"."post_hashtags" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."posts" "p"
  WHERE (("p"."id" = "post_hashtags"."post_id") AND ("p"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can insert own review requests" ON "public"."review_requests" FOR INSERT WITH CHECK (("requester_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can insert own reviewer score" ON "public"."reviewer_scores" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can insert reviews for others apps" ON "public"."reviews" FOR INSERT WITH CHECK ((("reviewer_id" = ( SELECT "auth"."uid"() AS "uid")) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."apps"
  WHERE (("apps"."id" = "reviews"."app_id") AND ("apps"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))))));



CREATE POLICY "Users can insert tags for own apps" ON "public"."app_tags" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."apps"
  WHERE (("apps"."id" = "app_tags"."app_id") AND ("apps"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "Users can update own api_keys" ON "public"."api_keys" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can update own apps" ON "public"."apps" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can update own draft reviews" ON "public"."reviews" FOR UPDATE USING ((("reviewer_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("status" = ANY (ARRAY['draft'::"text", 'submitted'::"text"]))));



CREATE POLICY "Users can update own review requests" ON "public"."review_requests" FOR UPDATE USING (("requester_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "Users can update own status" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id")) WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own api_keys" ON "public"."api_keys" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view own heartbeats" ON "public"."heartbeats" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view own reports" ON "public"."reports" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "reporter_id"));



CREATE POLICY "Users can view their own daily_stats" ON "public"."daily_stats" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."api_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."app_tags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."apps" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."blocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "blocks_delete" ON "public"."blocks" FOR DELETE TO "authenticated" USING (("blocker_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "blocks_insert" ON "public"."blocks" FOR INSERT TO "authenticated" WITH CHECK (("blocker_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "blocks_select" ON "public"."blocks" FOR SELECT TO "authenticated" USING (("blocker_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_delete_own" ON "public"."categories" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND ("is_default" = false)));



CREATE POLICY "categories_insert_own" ON "public"."categories" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND ("is_default" = false)));



CREATE POLICY "categories_select_own_and_default" ON "public"."categories" FOR SELECT TO "authenticated" USING (((("is_default" = true) AND ("user_id" IS NULL)) OR (( SELECT "auth"."uid"() AS "uid") = "user_id")));



CREATE POLICY "categories_update_own" ON "public"."categories" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") AND ("is_default" = false)));



ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "comments_delete" ON "public"."comments" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "comments_insert" ON "public"."comments" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "comments_select" ON "public"."comments" FOR SELECT TO "authenticated" USING (((NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE (("blocks"."blocker_id" = "auth"."uid"()) AND ("blocks"."blocked_id" = "comments"."user_id"))))) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE (("blocks"."blocker_id" = "comments"."user_id") AND ("blocks"."blocked_id" = "auth"."uid"())))))));



CREATE POLICY "comments_update" ON "public"."comments" FOR UPDATE TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("created_at" > ("now"() - '24:00:00'::interval)))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."daily_stats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."follows" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "follows_delete" ON "public"."follows" FOR DELETE TO "authenticated" USING (("follower_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "follows_insert" ON "public"."follows" FOR INSERT TO "authenticated" WITH CHECK (("follower_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "follows_select" ON "public"."follows" FOR SELECT TO "authenticated" USING ((("follower_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("following_id" = ( SELECT "auth"."uid"() AS "uid"))));



ALTER TABLE "public"."global_stats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."hashtags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."heartbeats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."likes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "likes_delete" ON "public"."likes" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "likes_insert" ON "public"."likes" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "likes_select" ON "public"."likes" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "logs_delete_own" ON "public"."logs" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "logs_insert_own" ON "public"."logs" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "logs_select_own" ON "public"."logs" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "logs_update_own" ON "public"."logs" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."mentions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "mentions_insert" ON "public"."mentions" FOR INSERT TO "authenticated" WITH CHECK (false);



CREATE POLICY "mentions_select" ON "public"."mentions" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."monthly_revenues" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "monthly_revenues_delete_own" ON "public"."monthly_revenues" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "monthly_revenues_insert_own" ON "public"."monthly_revenues" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "monthly_revenues_select_own" ON "public"."monthly_revenues" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "monthly_revenues_update_own" ON "public"."monthly_revenues" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_delete" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_insert" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_select" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "notifications_update" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."post_hashtags" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."posts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "posts_delete" ON "public"."posts" FOR DELETE TO "authenticated" USING (false);



CREATE POLICY "posts_insert" ON "public"."posts" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "posts_select" ON "public"."posts" FOR SELECT TO "authenticated" USING ((("is_deleted" = false) AND (("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (("visibility" = 'public'::"text") AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE ((("blocks"."blocker_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("blocks"."blocked_id" = "posts"."user_id")) OR (("blocks"."blocker_id" = "posts"."user_id") AND ("blocks"."blocked_id" = ( SELECT "auth"."uid"() AS "uid")))))))) OR (("visibility" = 'followers_only'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."follows"
  WHERE (("follows"."follower_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("follows"."following_id" = "posts"."user_id")))) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE ((("blocks"."blocker_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("blocks"."blocked_id" = "posts"."user_id")) OR (("blocks"."blocker_id" = "posts"."user_id") AND ("blocks"."blocked_id" = ( SELECT "auth"."uid"() AS "uid")))))))))));



CREATE POLICY "posts_update" ON "public"."posts" FOR UPDATE TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("created_at" > ("now"() - '24:00:00'::interval)))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "profiles_select_sns" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR (("visibility" = 'public'::"text") AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE ((("blocks"."blocker_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("blocks"."blocked_id" = "profiles"."id")) OR (("blocks"."blocker_id" = "profiles"."id") AND ("blocks"."blocked_id" = ( SELECT "auth"."uid"() AS "uid")))))))) OR (("visibility" = 'followers_only'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."follows"
  WHERE (("follows"."follower_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("follows"."following_id" = "profiles"."id")))) AND (NOT (EXISTS ( SELECT 1
   FROM "public"."blocks"
  WHERE ((("blocks"."blocker_id" = ( SELECT "auth"."uid"() AS "uid")) AND ("blocks"."blocked_id" = "profiles"."id")) OR (("blocks"."blocker_id" = "profiles"."id") AND ("blocks"."blocked_id" = ( SELECT "auth"."uid"() AS "uid"))))))))));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



ALTER TABLE "public"."reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."review_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviewer_scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."subscriptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "subscriptions_select_own" ON "public"."subscriptions" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."clear_stale_profile_status"() TO "anon";
GRANT ALL ON FUNCTION "public"."clear_stale_profile_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_stale_profile_status"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decrement_hashtag_post_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."decrement_hashtag_post_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."decrement_hashtag_post_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."extract_and_link_hashtags"("p_post_id" "uuid", "p_content" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."extract_and_link_hashtags"("p_post_id" "uuid", "p_content" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."extract_and_link_hashtags"("p_post_id" "uuid", "p_content" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."extract_and_link_mentions"("p_post_id" "uuid", "p_comment_id" "uuid", "p_content" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."extract_and_link_mentions"("p_post_id" "uuid", "p_comment_id" "uuid", "p_content" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."extract_and_link_mentions"("p_post_id" "uuid", "p_comment_id" "uuid", "p_content" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_category_breakdown"("p_user_id" "uuid", "p_period" "text", "p_week_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_category_breakdown"("p_user_id" "uuid", "p_period" "text", "p_week_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_category_breakdown"("p_user_id" "uuid", "p_period" "text", "p_week_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_or_create_user_categories"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_or_create_user_categories"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_or_create_user_categories"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_summary_stats"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_summary_stats"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_summary_stats"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_percentile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_percentile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_percentile"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_weekly_breakdown"("p_user_id" "uuid", "p_week_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_weekly_breakdown"("p_user_id" "uuid", "p_week_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_weekly_breakdown"("p_user_id" "uuid", "p_week_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_weekly_comparison"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_weekly_comparison"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_weekly_comparison"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_hashtag_post_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_hashtag_post_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_hashtag_post_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_daily_stats"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_daily_stats"("target_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_daily_stats"("target_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats"("target_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats"("target_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_daily_stats_for"("p_user_id" "uuid", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats_for"("p_user_id" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_daily_stats_for"("p_user_id" "uuid", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_global_stats"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_global_stats"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_global_stats"() TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_follows_on_block"() TO "anon";
GRANT ALL ON FUNCTION "public"."remove_follows_on_block"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_follows_on_block"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_extract_comment_mentions"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_extract_comment_mentions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_extract_comment_mentions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_extract_hashtags"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_extract_hashtags"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_extract_hashtags"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_extract_post_mentions"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_extract_post_mentions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_extract_post_mentions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_app_rating_on_review"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_app_rating_on_review"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_app_rating_on_review"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_app_rating_on_review_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_app_rating_on_review_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_app_rating_on_review_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_apps_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_apps_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_apps_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_comments_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_comments_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_comments_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_comments_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_comments_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_comments_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_follow_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_follow_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_follow_counts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_post_comments_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_post_likes_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_posts_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_posts_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_posts_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_posts_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_posts_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_posts_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_repost_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_repost_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_repost_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_review_requests_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_review_requests_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_review_requests_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_reviewer_scores_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_reviewer_scores_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_reviewer_scores_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_reviews_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_reviews_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_reviews_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON TABLE "public"."api_keys" TO "anon";
GRANT ALL ON TABLE "public"."api_keys" TO "authenticated";
GRANT ALL ON TABLE "public"."api_keys" TO "service_role";



GRANT ALL ON TABLE "public"."app_tags" TO "anon";
GRANT ALL ON TABLE "public"."app_tags" TO "authenticated";
GRANT ALL ON TABLE "public"."app_tags" TO "service_role";



GRANT ALL ON TABLE "public"."apps" TO "anon";
GRANT ALL ON TABLE "public"."apps" TO "authenticated";
GRANT ALL ON TABLE "public"."apps" TO "service_role";



GRANT ALL ON TABLE "public"."blocks" TO "anon";
GRANT ALL ON TABLE "public"."blocks" TO "authenticated";
GRANT ALL ON TABLE "public"."blocks" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";



GRANT ALL ON TABLE "public"."daily_stats" TO "anon";
GRANT ALL ON TABLE "public"."daily_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_stats" TO "service_role";



GRANT ALL ON TABLE "public"."follows" TO "anon";
GRANT ALL ON TABLE "public"."follows" TO "authenticated";
GRANT ALL ON TABLE "public"."follows" TO "service_role";



GRANT ALL ON TABLE "public"."global_stats" TO "anon";
GRANT ALL ON TABLE "public"."global_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."global_stats" TO "service_role";



GRANT ALL ON TABLE "public"."hashtags" TO "anon";
GRANT ALL ON TABLE "public"."hashtags" TO "authenticated";
GRANT ALL ON TABLE "public"."hashtags" TO "service_role";



GRANT ALL ON TABLE "public"."heartbeats" TO "anon";
GRANT ALL ON TABLE "public"."heartbeats" TO "authenticated";
GRANT ALL ON TABLE "public"."heartbeats" TO "service_role";



GRANT ALL ON TABLE "public"."likes" TO "anon";
GRANT ALL ON TABLE "public"."likes" TO "authenticated";
GRANT ALL ON TABLE "public"."likes" TO "service_role";



GRANT ALL ON TABLE "public"."logs" TO "anon";
GRANT ALL ON TABLE "public"."logs" TO "authenticated";
GRANT ALL ON TABLE "public"."logs" TO "service_role";



GRANT ALL ON TABLE "public"."mentions" TO "anon";
GRANT ALL ON TABLE "public"."mentions" TO "authenticated";
GRANT ALL ON TABLE "public"."mentions" TO "service_role";



GRANT ALL ON TABLE "public"."monthly_revenues" TO "anon";
GRANT ALL ON TABLE "public"."monthly_revenues" TO "authenticated";
GRANT ALL ON TABLE "public"."monthly_revenues" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."post_hashtags" TO "anon";
GRANT ALL ON TABLE "public"."post_hashtags" TO "authenticated";
GRANT ALL ON TABLE "public"."post_hashtags" TO "service_role";



GRANT ALL ON TABLE "public"."posts" TO "anon";
GRANT ALL ON TABLE "public"."posts" TO "authenticated";
GRANT ALL ON TABLE "public"."posts" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."reports" TO "anon";
GRANT ALL ON TABLE "public"."reports" TO "authenticated";
GRANT ALL ON TABLE "public"."reports" TO "service_role";



GRANT ALL ON TABLE "public"."review_requests" TO "anon";
GRANT ALL ON TABLE "public"."review_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."review_requests" TO "service_role";



GRANT ALL ON TABLE "public"."reviewer_scores" TO "anon";
GRANT ALL ON TABLE "public"."reviewer_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."reviewer_scores" TO "service_role";



GRANT ALL ON TABLE "public"."reviews" TO "anon";
GRANT ALL ON TABLE "public"."reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."reviews" TO "service_role";



GRANT ALL ON TABLE "public"."subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."trending_hashtags" TO "anon";
GRANT ALL ON TABLE "public"."trending_hashtags" TO "authenticated";
GRANT ALL ON TABLE "public"."trending_hashtags" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






