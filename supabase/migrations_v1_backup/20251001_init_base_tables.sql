-- =============================================================
-- 基盤テーブル作成
-- profiles, categories, logs, monthly_revenues,
-- subscriptions, comparisons_cache
-- auth.users との連携トリガー含む
-- =============================================================

-- 1. profiles
CREATE TABLE IF NOT EXISTS profiles (
  id                   uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                text        NOT NULL UNIQUE,
  display_name         text,
  avatar_url           text,
  role                 text        NOT NULL DEFAULT 'developer',
  age_group            text        CHECK (age_group IN ('10代', '20代', '30代', '40代', '50代以上')),
  gender               text        CHECK (gender IN ('男性', '女性', 'その他', '回答しない')),
  occupation           text        CHECK (occupation IN ('会社員', 'フリーランス', '学生', 'その他')),
  work_type            text        CHECK (work_type IN ('副業', '本業')),
  income_status        text        CHECK (income_status IN (
    'no_income', 'under_10k', '10k_to_50k', '50k_to_100k',
    '100k_to_200k', '200k_to_300k', '300k_to_500k', 'over_500k'
  )),
  experience_years     text        CHECK (experience_years IN (
    'under_3_months', 'three_to_six_months', 'six_to_twelve_months',
    'one_to_two_years', 'two_to_three_years', 'three_to_four_years',
    'four_to_five_years', 'over_five_years'
  )),
  bio                  text,
  timezone             text        NOT NULL DEFAULT 'Asia/Tokyo',
  notification_enabled boolean     NOT NULL DEFAULT true,
  onboarding_completed boolean     NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_role_work ON profiles (role, work_type);
CREATE INDEX IF NOT EXISTS idx_profiles_created ON profiles (created_at);

-- 2. categories
CREATE TABLE IF NOT EXISTS categories (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        REFERENCES profiles(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  color         text        NOT NULL,
  icon          text,
  is_active     boolean     NOT NULL DEFAULT true,
  is_default    boolean     NOT NULL DEFAULT false,
  display_order integer     NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_categories_user_active ON categories (user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_categories_default ON categories (is_default);

-- 3. logs
CREATE TABLE IF NOT EXISTS logs (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title            text        NOT NULL DEFAULT 'その他',
  category_id      uuid        NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  started_at       timestamptz NOT NULL,
  ended_at         timestamptz NOT NULL,
  duration_minutes integer     NOT NULL CHECK (duration_minutes >= 0),
  memo             text,
  is_timer         boolean     NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_logs_user_started ON logs (user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_logs_user_category ON logs (user_id, category_id);
CREATE INDEX IF NOT EXISTS idx_logs_user_created ON logs (user_id, created_at DESC);

-- 4. monthly_revenues
CREATE TABLE IF NOT EXISTS monthly_revenues (
  id         uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid          NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  year       integer       NOT NULL,
  month      integer       NOT NULL CHECK (month BETWEEN 1 AND 12),
  revenue    decimal(10,2) NOT NULL DEFAULT 0,
  note       text,
  created_at timestamptz   NOT NULL DEFAULT now(),
  updated_at timestamptz   NOT NULL DEFAULT now(),
  UNIQUE (user_id, year, month)
);

CREATE INDEX IF NOT EXISTS idx_revenues_user_period ON monthly_revenues (user_id, year DESC, month DESC);

-- 5. subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  uuid        NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  status                   text        NOT NULL DEFAULT 'inactive'
                           CHECK (status IN ('active', 'inactive', 'canceled', 'past_due')),
  plan_type                text        NOT NULL DEFAULT 'free'
                           CHECK (plan_type IN ('free', 'premium')),
  provider                 text        CHECK (provider IN ('stripe', 'app_store')),
  provider_subscription_id text,
  provider_customer_id     text,
  current_period_start     timestamptz,
  current_period_end       timestamptz,
  cancel_at_period_end     boolean     NOT NULL DEFAULT false,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions (status, plan_type);
CREATE INDEX IF NOT EXISTS idx_subscriptions_provider ON subscriptions (provider, provider_subscription_id);

-- 6. comparisons_cache
CREATE TABLE IF NOT EXISTS comparisons_cache (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key  text        NOT NULL,
  filters    jsonb       DEFAULT '{}',
  data       jsonb       NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cache_key, filters)
);

CREATE INDEX IF NOT EXISTS idx_cache_expires ON comparisons_cache (expires_at);

-- =============================================================
-- updated_at 自動更新トリガー（共通）
-- =============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_logs_updated_at
  BEFORE UPDATE ON logs FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_revenues_updated_at
  BEFORE UPDATE ON monthly_revenues FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================
-- auth.users 新規登録時に profiles を自動作成
-- =============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- =============================================================
-- デフォルトカテゴリの挿入
-- =============================================================
INSERT INTO categories (user_id, name, color, icon, is_default, display_order) VALUES
  (NULL, 'コーディング',   '#3B82F6', 'chevron.left.forwardslash.chevron.right', true, 1),
  (NULL, 'デザイン',       '#8B5CF6', 'paintbrush',                               true, 2),
  (NULL, '学習',           '#10B981', 'book',                                     true, 3),
  (NULL, 'ミーティング',   '#F59E0B', 'person.2',                                 true, 4),
  (NULL, 'ドキュメント',   '#6366F1', 'doc.text',                                 true, 5),
  (NULL, 'その他',         '#6B7280', 'ellipsis.circle',                          true, 6)
ON CONFLICT DO NOTHING;

-- =============================================================
-- Storage bucket for avatars
-- =============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT DO NOTHING;

CREATE POLICY "Users can read own avatar" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
