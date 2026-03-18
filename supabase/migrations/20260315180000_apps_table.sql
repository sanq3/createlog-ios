-- アプリショーケース: apps テーブル作成
-- ユーザーが開発したアプリを登録・公開するためのテーブル

CREATE TABLE IF NOT EXISTS apps (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  description   text,
  icon_url      text,
  screenshots   jsonb       DEFAULT '[]'::jsonb,
  platform      text        NOT NULL DEFAULT 'other'
                            CHECK (platform IN ('ios', 'android', 'web', 'other')),
  app_url       text,
  store_url     text,
  github_url    text,
  status        text        NOT NULL DEFAULT 'draft'
                            CHECK (status IN ('draft', 'published', 'archived')),
  category      text,
  avg_rating    decimal(3,2) DEFAULT 0,
  review_count  integer     DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- インデックス
CREATE INDEX idx_apps_user_id ON apps(user_id);
CREATE INDEX idx_apps_status ON apps(status);
CREATE INDEX idx_apps_platform ON apps(platform);
CREATE INDEX idx_apps_category ON apps(category);
CREATE INDEX idx_apps_created_at ON apps(created_at DESC);
CREATE INDEX idx_apps_avg_rating ON apps(avg_rating DESC);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_apps_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_apps_updated_at
  BEFORE UPDATE ON apps
  FOR EACH ROW
  EXECUTE FUNCTION update_apps_updated_at();

-- RLS有効化
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;

-- 公開アプリは全認証ユーザーが閲覧可能
CREATE POLICY "Published apps are viewable by authenticated users"
  ON apps FOR SELECT
  USING (
    status = 'published'
    OR user_id = (SELECT auth.uid())
  );

-- 自分のアプリのみ作成可能
CREATE POLICY "Users can insert own apps"
  ON apps FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));

-- 自分のアプリのみ更新可能
CREATE POLICY "Users can update own apps"
  ON apps FOR UPDATE
  USING (user_id = (SELECT auth.uid()));

-- 自分のアプリのみ削除可能
CREATE POLICY "Users can delete own apps"
  ON apps FOR DELETE
  USING (user_id = (SELECT auth.uid()));
