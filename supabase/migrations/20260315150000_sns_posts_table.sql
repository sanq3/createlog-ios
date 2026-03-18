-- =============================================================
-- Phase 1.1: posts テーブル作成
-- SNS投稿を管理する。ログと紐付け可能。
-- =============================================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS posts (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  log_id        uuid        REFERENCES logs(id) ON DELETE SET NULL,
  content       text        NOT NULL CHECK (char_length(content) <= 2000),
  visibility    text        NOT NULL DEFAULT 'public'
                CHECK (visibility IN ('public', 'followers_only', 'private')),
  likes_count   integer     NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
  is_deleted    boolean     NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- コメント
COMMENT ON TABLE  posts              IS 'SNS投稿';
COMMENT ON COLUMN posts.user_id      IS '投稿者のユーザーID';
COMMENT ON COLUMN posts.log_id       IS '紐付け作業ログ（NULL許可）';
COMMENT ON COLUMN posts.content      IS '投稿本文（最大2000文字）';
COMMENT ON COLUMN posts.visibility   IS '公開範囲: public / followers_only / private';
COMMENT ON COLUMN posts.likes_count  IS 'いいね数（非正規化カウンタ）';
COMMENT ON COLUMN posts.is_deleted   IS '論理削除フラグ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_posts_user_created
  ON posts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_posts_feed
  ON posts (visibility, is_deleted, created_at DESC)
  WHERE is_deleted = false;

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_posts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_posts_updated_at ON posts;
CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_posts_updated_at();

-- =============================================================
-- RLS 有効化のみ（ポリシーは blocks/follows テーブル作成後に適用）
-- → 20260315150005_sns_profiles_columns.sql で一括設定
-- =============================================================
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
