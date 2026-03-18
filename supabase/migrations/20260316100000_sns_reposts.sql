-- Migration: Add repost & quote support to posts table
-- Creates posts table (if not exists) with repost_of_id, quote_of_id, repost_count
-- Adds triggers for automatic repost_count maintenance

-- =============================================================================
-- 1. Create posts table with repost/quote columns
-- =============================================================================
CREATE TABLE IF NOT EXISTS posts (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content       text,
  repost_of_id  uuid        REFERENCES posts(id) ON DELETE CASCADE,
  quote_of_id   uuid        REFERENCES posts(id) ON DELETE CASCADE,
  like_count    integer     NOT NULL DEFAULT 0,
  repost_count  integer     NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  -- A pure repost has no content; a quote or original post requires content
  CONSTRAINT posts_content_check CHECK (
    (repost_of_id IS NOT NULL) OR (content IS NOT NULL AND content <> '')
  ),
  -- A post cannot be both a repost and a quote
  CONSTRAINT posts_repost_or_quote CHECK (
    NOT (repost_of_id IS NOT NULL AND quote_of_id IS NOT NULL)
  )
);

-- =============================================================================
-- 2. Indexes
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_posts_user_id_created
  ON posts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_posts_repost_of_id
  ON posts (repost_of_id)
  WHERE repost_of_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_posts_quote_of_id
  ON posts (quote_of_id)
  WHERE quote_of_id IS NOT NULL;

-- Prevent double repost by the same user
CREATE UNIQUE INDEX IF NOT EXISTS idx_posts_unique_repost
  ON posts (user_id, repost_of_id)
  WHERE repost_of_id IS NOT NULL;

-- =============================================================================
-- 3. Trigger: auto-update repost_count on the original post
-- =============================================================================
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

-- =============================================================================
-- 4. Trigger: auto-update updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION update_posts_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_posts_updated_at ON posts;
CREATE TRIGGER trg_posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_posts_updated_at();

-- =============================================================================
-- 5. RLS policies
-- =============================================================================
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Anyone can read posts (public timeline)
CREATE POLICY posts_select_all
  ON posts FOR SELECT
  USING (true);

-- Authenticated users can create posts (original, repost, or quote)
CREATE POLICY posts_insert_own
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own posts
CREATE POLICY posts_update_own
  ON posts FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own posts (including reposts)
CREATE POLICY posts_delete_own
  ON posts FOR DELETE
  USING (auth.uid() = user_id);
