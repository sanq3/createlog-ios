-- =============================================================
-- 通知タイプ拡張 + メンション抽出機能
--
-- 1. notifications の CHECK 制約を拡張
--    (mention, comment, repost, quote を追加)
-- 2. mentions テーブル作成
-- 3. メンション自動抽出トリガー
-- 4. comment_id カラムを notifications に追加
-- =============================================================

-- 1. notifications の CHECK 制約を拡張
-- 既存の制約を削除して再作成
DO $$
DECLARE
  constraint_name text;
BEGIN
  -- type カラムの CHECK 制約名を取得
  SELECT con.conname INTO constraint_name
  FROM pg_constraint con
  JOIN pg_attribute att ON att.attnum = ANY(con.conkey) AND att.attrelid = con.conrelid
  WHERE con.conrelid = 'notifications'::regclass
    AND att.attname = 'type'
    AND con.contype = 'c';

  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE notifications DROP CONSTRAINT %I', constraint_name);
  END IF;
END
$$;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'follow', 'like', 'comment', 'mention',
    'repost', 'quote',
    'review_request', 'review_completed', 'milestone'
  ));

COMMENT ON COLUMN notifications.type IS '通知タイプ: follow / like / comment / mention / repost / quote / review_request / review_completed / milestone';

-- 2. comment_id カラムを notifications に追加
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'comment_id') THEN
    ALTER TABLE notifications ADD COLUMN comment_id uuid REFERENCES comments(id) ON DELETE CASCADE;
  END IF;
END
$$;

COMMENT ON COLUMN notifications.comment_id IS '関連するコメントID（コメント/メンション通知で使用）';

-- 3. mentions テーブル作成
CREATE TABLE IF NOT EXISTS mentions (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid        REFERENCES posts(id) ON DELETE CASCADE,
  comment_id uuid        REFERENCES comments(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),

  -- 投稿かコメントのどちらかに紐づく
  CONSTRAINT mentions_source_check CHECK (
    (post_id IS NOT NULL AND comment_id IS NULL) OR
    (post_id IS NULL AND comment_id IS NOT NULL)
  )
);

COMMENT ON TABLE  mentions            IS 'メンション（@ユーザー）';
COMMENT ON COLUMN mentions.post_id    IS 'メンション元の投稿ID';
COMMENT ON COLUMN mentions.comment_id IS 'メンション元のコメントID';
COMMENT ON COLUMN mentions.user_id    IS 'メンションされたユーザーID';

CREATE INDEX IF NOT EXISTS idx_mentions_user
  ON mentions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_mentions_post
  ON mentions (post_id)
  WHERE post_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_mentions_comment
  ON mentions (comment_id)
  WHERE comment_id IS NOT NULL;

-- 重複メンション防止
CREATE UNIQUE INDEX IF NOT EXISTS idx_mentions_unique_post
  ON mentions (post_id, user_id)
  WHERE post_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mentions_unique_comment
  ON mentions (comment_id, user_id)
  WHERE comment_id IS NOT NULL;

-- RLS
ALTER TABLE mentions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mentions_select" ON mentions;
CREATE POLICY "mentions_select" ON mentions
  FOR SELECT
  TO authenticated
  USING (true);

-- INSERT は抽出トリガー経由（SECURITY DEFINER）のみ
-- ユーザー直接 INSERT は不要だが、service_role のために許可
DROP POLICY IF EXISTS "mentions_insert" ON mentions;
CREATE POLICY "mentions_insert" ON mentions
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

-- 4. メンション自動抽出関数
-- ハッシュタグ抽出と同様のパターンで @handle を検出
CREATE OR REPLACE FUNCTION extract_and_link_mentions(
  p_post_id    uuid,
  p_comment_id uuid,
  p_content    text
)
RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 5. 投稿のメンション自動抽出トリガー
CREATE OR REPLACE FUNCTION trigger_extract_post_mentions()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content IS NOT NULL THEN
    PERFORM extract_and_link_mentions(NEW.id, NULL, NEW.content);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_posts_extract_mentions ON posts;
CREATE TRIGGER trg_posts_extract_mentions
  AFTER INSERT OR UPDATE OF content ON posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_extract_post_mentions();

-- 6. コメントのメンション自動抽出トリガー
CREATE OR REPLACE FUNCTION trigger_extract_comment_mentions()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.content IS NOT NULL THEN
    PERFORM extract_and_link_mentions(NULL, NEW.id, NEW.content);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_comments_extract_mentions ON comments;
CREATE TRIGGER trg_comments_extract_mentions
  AFTER INSERT OR UPDATE OF content ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_extract_comment_mentions();
