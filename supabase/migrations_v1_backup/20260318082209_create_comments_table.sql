-- =============================================================
-- comments テーブル作成
-- 投稿へのコメント機能。スレッド（返信）対応。
-- =============================================================

CREATE TABLE IF NOT EXISTS comments (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id           uuid        NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id           uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id uuid        REFERENCES comments(id) ON DELETE CASCADE,
  content           text        NOT NULL CHECK (char_length(content) <= 1000),
  is_deleted        boolean     NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  comments                   IS '投稿へのコメント';
COMMENT ON COLUMN comments.post_id           IS '対象の投稿ID';
COMMENT ON COLUMN comments.user_id           IS 'コメント投稿者のユーザーID';
COMMENT ON COLUMN comments.parent_comment_id IS '返信先コメントID（NULLならトップレベルコメント）';
COMMENT ON COLUMN comments.content           IS 'コメント本文（最大1000文字）';
COMMENT ON COLUMN comments.is_deleted        IS '論理削除フラグ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_comments_post_created
  ON comments (post_id, created_at ASC)
  WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_comments_user_created
  ON comments (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_comments_parent
  ON comments (parent_comment_id)
  WHERE parent_comment_id IS NOT NULL;

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_comments_updated_at ON comments;
CREATE TRIGGER trg_comments_updated_at
  BEFORE UPDATE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comments_updated_at();

-- =============================================================
-- posts テーブルに comments_count カラム追加
-- =============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'comments_count') THEN
    ALTER TABLE posts ADD COLUMN comments_count integer NOT NULL DEFAULT 0 CHECK (comments_count >= 0);
  END IF;
END
$$;

COMMENT ON COLUMN posts.comments_count IS 'コメント数（非正規化カウンタ）';

-- comments_count 自動更新トリガー
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_comments_count ON comments;
CREATE TRIGGER trg_comments_count
  AFTER INSERT OR DELETE OR UPDATE OF is_deleted ON comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comments_count();

-- =============================================================
-- RLS ポリシー
-- =============================================================
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- SELECT: 公開投稿のコメントは閲覧可（ブロック除外）
DROP POLICY IF EXISTS "comments_select" ON comments;
CREATE POLICY "comments_select" ON comments
  FOR SELECT
  TO authenticated
  USING (
    is_deleted = false
    AND (
      user_id = (SELECT auth.uid())
      OR NOT EXISTS (
        SELECT 1 FROM blocks
        WHERE (blocker_id = (SELECT auth.uid()) AND blocked_id = comments.user_id)
           OR (blocker_id = comments.user_id AND blocked_id = (SELECT auth.uid()))
      )
    )
  );

-- INSERT: 認証済みユーザーが自分のコメントを作成
DROP POLICY IF EXISTS "comments_insert" ON comments;
CREATE POLICY "comments_insert" ON comments
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- UPDATE: 自分のコメント、作成から24時間以内
DROP POLICY IF EXISTS "comments_update" ON comments;
CREATE POLICY "comments_update" ON comments
  FOR UPDATE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND created_at > now() - interval '24 hours'
  )
  WITH CHECK (user_id = (SELECT auth.uid()));

-- DELETE: ユーザーによる物理削除は禁止（論理削除のみ）
DROP POLICY IF EXISTS "comments_delete" ON comments;
CREATE POLICY "comments_delete" ON comments
  FOR DELETE
  TO authenticated
  USING (false);
