-- =============================================================
-- Fix: posts テーブル統合
-- 20260315150000 と 20260316100000 の競合を解消
--
-- 問題点:
--   1. likes_count vs like_count の命名不一致
--   2. 20260316100000 の RLS USING(true) が
--      20260315150005 の visibility/block 対応ポリシーを上書き
--   3. repost/quote カラムが初期定義に含まれていない
--
-- 対応:
--   1. repost_of_id, quote_of_id, repost_count カラムを追加
--   2. like_count を likes_count に統一
--   3. 不正な RLS ポリシーを削除（正しいポリシーは 150005 で適用済み）
--   4. 重複リポスト防止のユニークインデックスを追加
--   5. コンテンツチェック制約を追加
-- =============================================================

-- 1. repost/quote カラムを追加
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'repost_of_id') THEN
    ALTER TABLE posts ADD COLUMN repost_of_id uuid REFERENCES posts(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'quote_of_id') THEN
    ALTER TABLE posts ADD COLUMN quote_of_id uuid REFERENCES posts(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'repost_count') THEN
    ALTER TABLE posts ADD COLUMN repost_count integer NOT NULL DEFAULT 0 CHECK (repost_count >= 0);
  END IF;
END
$$;

-- 2. like_count → likes_count 統一
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'like_count')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'likes_count') THEN
    ALTER TABLE posts RENAME COLUMN like_count TO likes_count;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'like_count')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'likes_count') THEN
    UPDATE posts SET likes_count = GREATEST(likes_count, like_count);
    ALTER TABLE posts DROP COLUMN like_count;
  END IF;
END
$$;

-- 3. 不正な RLS ポリシーを削除
-- 20260316100000 の USING(true) ポリシーはセキュリティリグレッション
-- 正しいポリシーは 20260315150005 で適用済み
DROP POLICY IF EXISTS "posts_select_all" ON posts;
DROP POLICY IF EXISTS "posts_insert_own" ON posts;
DROP POLICY IF EXISTS "posts_update_own" ON posts;
DROP POLICY IF EXISTS "posts_delete_own" ON posts;

-- 4. リポスト/引用用インデックス
CREATE INDEX IF NOT EXISTS idx_posts_repost_of_id
  ON posts (repost_of_id)
  WHERE repost_of_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_posts_quote_of_id
  ON posts (quote_of_id)
  WHERE quote_of_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_unique_repost
  ON posts (user_id, repost_of_id)
  WHERE repost_of_id IS NOT NULL;

-- 5. コンテンツ/リポスト制約
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'posts_repost_or_quote'
  ) THEN
    ALTER TABLE posts ADD CONSTRAINT posts_repost_or_quote
      CHECK (NOT (repost_of_id IS NOT NULL AND quote_of_id IS NOT NULL));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'posts_content_repost_check'
  ) THEN
    ALTER TABLE posts ADD CONSTRAINT posts_content_repost_check
      CHECK ((repost_of_id IS NOT NULL) OR (content IS NOT NULL AND content <> ''));
  END IF;
END
$$;

-- 6. repost_count 自動更新トリガー
CREATE OR REPLACE FUNCTION update_repost_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
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

DROP TRIGGER IF EXISTS trg_repost_count_insert ON posts;
CREATE TRIGGER trg_repost_count_insert
  AFTER INSERT ON posts
  FOR EACH ROW
  WHEN (NEW.repost_of_id IS NOT NULL)
  EXECUTE FUNCTION update_repost_count();

DROP TRIGGER IF EXISTS trg_repost_count_delete ON posts;
CREATE TRIGGER trg_repost_count_delete
  AFTER DELETE ON posts
  FOR EACH ROW
  WHEN (OLD.repost_of_id IS NOT NULL)
  EXECUTE FUNCTION update_repost_count();

COMMENT ON COLUMN posts.repost_of_id IS 'リポスト元の投稿ID（NULLならオリジナル投稿）';
COMMENT ON COLUMN posts.quote_of_id IS '引用元の投稿ID（NULLなら引用なし）';
COMMENT ON COLUMN posts.repost_count IS 'リポスト数（非正規化カウンタ）';
