-- ================================================
-- Phase 0.3: monthly_revenues スキーマ統一
--
-- 問題: フロント側が month="YYYY-MM" + amount で読み書きしているが、
--       SQL側は year/month/revenue で定義されている
-- 解決: SQL側（year/month/revenue）を正とし、フロント側を修正
--
-- このマイグレーションでは、万が一 month カラムが text 型になっている
-- 本番DBに対応するため、冪等な修正を行う
-- ================================================

-- 1. month カラムが text 型の場合のみデータ移行
-- （本番DBが既に integer 型なら何もしない）
DO $$
DECLARE
  v_month_type TEXT;
BEGIN
  -- month カラムの型を確認
  SELECT data_type INTO v_month_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'monthly_revenues'
    AND column_name = 'month';

  IF v_month_type IS NOT NULL AND v_month_type IN ('text', 'character varying') THEN
    -- text 型の場合: "YYYY-MM" 形式を year/month に分解

    -- year カラムが存在しない場合は追加
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'monthly_revenues'
        AND column_name = 'year'
    ) THEN
      ALTER TABLE monthly_revenues ADD COLUMN year INTEGER;
    END IF;

    -- amount カラムが存在する場合、revenue カラムにコピー
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'monthly_revenues'
        AND column_name = 'amount'
    ) THEN
      -- revenue カラムが存在しない場合は追加
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'monthly_revenues'
          AND column_name = 'revenue'
      ) THEN
        ALTER TABLE monthly_revenues ADD COLUMN revenue DECIMAL(10,2) NOT NULL DEFAULT 0;
      END IF;

      -- amount → revenue にデータ移行
      UPDATE monthly_revenues SET revenue = amount WHERE revenue = 0 AND amount > 0;
    END IF;

    -- month (text) → year/month (integer) にデータ移行
    -- 2ステップで実行: text型のmonthを同一UPDATE文で読み書きすると型変換エラーのリスクがあるため
    -- Step 1: year を先に埋める（month はまだ text のまま）
    UPDATE monthly_revenues
    SET year = EXTRACT(YEAR FROM (month || '-01')::date)::integer
    WHERE year IS NULL;

    -- Step 2: month を text → integer に変換（ALTER TABLE で型変更）
    ALTER TABLE monthly_revenues
      ALTER COLUMN month TYPE INTEGER
      USING EXTRACT(MONTH FROM (month || '-01')::date)::integer;

    RAISE NOTICE 'monthly_revenues: migrated text month to integer year/month';
  END IF;

  -- year カラムが存在し integer 型の場合は既に正しいスキーマ
  -- 何もしない
END;
$$;

-- 2. 制約の確認・追加（冪等）
-- year の CHECK 制約
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'monthly_revenues_year_check'
  ) THEN
    -- year カラムが integer で CHECK がない場合のみ追加
    BEGIN
      ALTER TABLE monthly_revenues
        ADD CONSTRAINT monthly_revenues_year_check
        CHECK (year >= 2020 AND year <= 2100);
    EXCEPTION WHEN others THEN
      -- 制約が既に存在する場合は無視
      NULL;
    END;
  END IF;
END;
$$;

-- month の CHECK 制約
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'monthly_revenues_month_check'
  ) THEN
    BEGIN
      ALTER TABLE monthly_revenues
        ADD CONSTRAINT monthly_revenues_month_check
        CHECK (month >= 1 AND month <= 12);
    EXCEPTION WHEN others THEN
      NULL;
    END;
  END IF;
END;
$$;

-- UNIQUE 制約の確認（user_id, year, month）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'monthly_revenues'
      AND indexname = 'monthly_revenues_user_id_year_month_key'
  ) THEN
    BEGIN
      ALTER TABLE monthly_revenues
        ADD CONSTRAINT monthly_revenues_user_id_year_month_key
        UNIQUE (user_id, year, month);
    EXCEPTION WHEN others THEN
      NULL;
    END;
  END IF;
END;
$$;
