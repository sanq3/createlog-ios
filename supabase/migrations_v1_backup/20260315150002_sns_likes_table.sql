-- =============================================================
-- Phase 1.1: likes テーブル作成
-- 投稿へのいいね
-- =============================================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS likes (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id    uuid        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  -- 同一ユーザー・同一投稿の重複禁止
  CONSTRAINT uq_likes_user_post UNIQUE (user_id, post_id)
);

-- コメント
COMMENT ON TABLE  likes          IS '投稿へのいいね';
COMMENT ON COLUMN likes.user_id  IS 'いいねしたユーザーID';
COMMENT ON COLUMN likes.post_id  IS '対象の投稿ID';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_likes_post
  ON likes (post_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_likes_user
  ON likes (user_id, created_at DESC);

-- =============================================================
-- likes_count 更新トリガー（posts.likes_count を自動更新）
-- =============================================================
CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_likes_count ON likes;
CREATE TRIGGER trg_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW
  EXECUTE FUNCTION update_post_likes_count();

-- =============================================================
-- RLS ポリシー
-- =============================================================
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- SELECT: 認証ユーザー全員が閲覧可能
DROP POLICY IF EXISTS "likes_select" ON likes;
CREATE POLICY "likes_select" ON likes
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERT: 自分のいいねのみ
DROP POLICY IF EXISTS "likes_insert" ON likes;
CREATE POLICY "likes_insert" ON likes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- UPDATE: いいねの更新は不要
-- ポリシーなし = 更新禁止

-- DELETE: 自分のいいねのみ取り消し可能
DROP POLICY IF EXISTS "likes_delete" ON likes;
CREATE POLICY "likes_delete" ON likes
  FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));
