-- ================================================
-- ハッシュタグ機能: テーブル・トリガー・RLS・インデックス
-- 前提: posts テーブルが既に存在すること
-- ================================================

-- ================================================
-- 1. hashtags テーブル
-- ================================================
CREATE TABLE IF NOT EXISTS hashtags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  post_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT hashtag_name_lowercase CHECK (name = lower(name))
);

CREATE INDEX idx_hashtags_name ON hashtags (name);
CREATE INDEX idx_hashtags_post_count ON hashtags (post_count DESC);

-- ================================================
-- 2. post_hashtags ジャンクションテーブル
-- ================================================
CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  hashtag_id UUID NOT NULL REFERENCES hashtags (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, hashtag_id)
);

CREATE INDEX idx_post_hashtags_hashtag ON post_hashtags (hashtag_id);
CREATE INDEX idx_post_hashtags_post ON post_hashtags (post_id);
CREATE INDEX idx_post_hashtags_created ON post_hashtags (created_at DESC);

-- ================================================
-- 3. post_count の自動インクリメント / デクリメント
-- ================================================
CREATE OR REPLACE FUNCTION increment_hashtag_post_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE hashtags
    SET post_count = post_count + 1
  WHERE id = NEW.hashtag_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

CREATE TRIGGER trg_increment_hashtag_count
  AFTER INSERT ON post_hashtags
  FOR EACH ROW EXECUTE FUNCTION increment_hashtag_post_count();

CREATE OR REPLACE FUNCTION decrement_hashtag_post_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE hashtags
    SET post_count = GREATEST(post_count - 1, 0)
  WHERE id = OLD.hashtag_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

CREATE TRIGGER trg_decrement_hashtag_count
  AFTER DELETE ON post_hashtags
  FOR EACH ROW EXECUTE FUNCTION decrement_hashtag_post_count();

-- ================================================
-- 4. 投稿内容からハッシュタグを自動抽出・リンク
-- ================================================
CREATE OR REPLACE FUNCTION extract_and_link_hashtags(
  p_post_id UUID,
  p_content TEXT
)
RETURNS VOID AS $$
DECLARE
  tag TEXT;
  tag_id UUID;
BEGIN
  -- 既存のリンクを削除（UPDATE 時に再計算するため）
  DELETE FROM post_hashtags WHERE post_id = p_post_id;

  -- #ハッシュタグ パターンを抽出（英数字・アンダースコア・日本語対応）
  FOR tag IN
    SELECT DISTINCT lower(m[1])
    FROM regexp_matches(p_content, '#([a-zA-Z0-9_\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]+)', 'g') AS m
  LOOP
    -- hashtags テーブルに UPSERT
    INSERT INTO hashtags (name)
      VALUES (tag)
      ON CONFLICT (name) DO NOTHING
      RETURNING id INTO tag_id;

    -- RETURNING が NULL の場合（既存）は SELECT で取得
    IF tag_id IS NULL THEN
      SELECT h.id INTO tag_id FROM hashtags h WHERE h.name = tag;
    END IF;

    -- ジャンクションテーブルにリンク
    INSERT INTO post_hashtags (post_id, hashtag_id)
      VALUES (p_post_id, tag_id)
      ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

-- ================================================
-- 5. posts INSERT/UPDATE 時に自動呼び出し
-- ================================================
CREATE OR REPLACE FUNCTION trigger_extract_hashtags()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM extract_and_link_hashtags(NEW.id, NEW.content);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = public, pg_temp;

CREATE TRIGGER trg_posts_extract_hashtags
  AFTER INSERT OR UPDATE OF content ON posts
  FOR EACH ROW EXECUTE FUNCTION trigger_extract_hashtags();

-- ================================================
-- 6. トレンドビュー（過去 24 時間）
-- ================================================
CREATE OR REPLACE VIEW trending_hashtags AS
SELECT
  h.id,
  h.name,
  h.post_count,
  COUNT(ph.post_id) AS recent_count
FROM hashtags h
JOIN post_hashtags ph ON ph.hashtag_id = h.id
WHERE ph.created_at > now() - INTERVAL '24 hours'
GROUP BY h.id, h.name, h.post_count
ORDER BY recent_count DESC, h.post_count DESC
LIMIT 20;

-- ================================================
-- 7. RLS ポリシー
-- ================================================
ALTER TABLE hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_hashtags ENABLE ROW LEVEL SECURITY;

-- hashtags: 認証済みユーザーは誰でも閲覧可能
CREATE POLICY "Authenticated users can view hashtags"
  ON hashtags FOR SELECT
  USING (auth.role() = 'authenticated');

-- post_hashtags: 認証済みユーザーは誰でも閲覧可能
CREATE POLICY "Authenticated users can view post_hashtags"
  ON post_hashtags FOR SELECT
  USING (auth.role() = 'authenticated');

-- post_hashtags: 自分の投稿のハッシュタグのみ INSERT 可能
CREATE POLICY "Users can insert own post hashtags"
  ON post_hashtags FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM posts p WHERE p.id = post_id AND p.user_id = auth.uid()
    )
  );

-- post_hashtags: 自分の投稿のハッシュタグのみ DELETE 可能
CREATE POLICY "Users can delete own post hashtags"
  ON post_hashtags FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM posts p WHERE p.id = post_id AND p.user_id = auth.uid()
    )
  );
