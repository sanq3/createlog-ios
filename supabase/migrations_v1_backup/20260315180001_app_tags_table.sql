-- アプリショーケース: app_tags テーブル作成
-- アプリに紐づくタグ（技術スタック、カテゴリ等）を管理

CREATE TABLE IF NOT EXISTS app_tags (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id     uuid        NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  tag        text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 同一アプリに同じタグは重複不可
CREATE UNIQUE INDEX idx_app_tags_unique ON app_tags(app_id, tag);
CREATE INDEX idx_app_tags_app_id ON app_tags(app_id);
CREATE INDEX idx_app_tags_tag ON app_tags(tag);

-- RLS有効化
ALTER TABLE app_tags ENABLE ROW LEVEL SECURITY;

-- タグ閲覧: 公開アプリのタグは全認証ユーザーが閲覧可能
CREATE POLICY "App tags are viewable when app is visible"
  ON app_tags FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM apps
      WHERE apps.id = app_tags.app_id
        AND (apps.status = 'published' OR apps.user_id = (SELECT auth.uid()))
    )
  );

-- タグ作成: 自分のアプリにのみタグ追加可能
CREATE POLICY "Users can insert tags for own apps"
  ON app_tags FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM apps
      WHERE apps.id = app_tags.app_id
        AND apps.user_id = (SELECT auth.uid())
    )
  );

-- タグ削除: 自分のアプリのタグのみ削除可能
CREATE POLICY "Users can delete tags for own apps"
  ON app_tags FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM apps
      WHERE apps.id = app_tags.app_id
        AND apps.user_id = (SELECT auth.uid())
    )
  );
