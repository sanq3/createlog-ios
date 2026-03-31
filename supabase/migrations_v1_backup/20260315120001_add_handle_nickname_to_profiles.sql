-- profiles テーブルに handle / nickname カラムを追加
-- コード側（authStore.profileColumns, profile-setup.tsx）で使用されているが
-- DB実体に存在しないため差分を解消する

-- handle: ユーザーハンドル（一意識別子、SNS機能で使用予定）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'handle'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN handle text;
  END IF;
END $$;

-- nickname: ニックネーム（display_name の別名として使用）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'nickname'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN nickname text;
  END IF;
END $$;

-- handle にユニークインデックスを追加（SNS機能でハンドル検索に使用）
-- NULL は許可（既存ユーザーには未設定のため）
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_handle
  ON public.profiles (handle)
  WHERE handle IS NOT NULL;

-- 既存ユーザーの nickname を display_name から補完
UPDATE public.profiles
  SET nickname = display_name
  WHERE nickname IS NULL
    AND display_name IS NOT NULL;
