-- =============================================================
-- Phase 1.1: profiles テーブルにSNS関連カラム追加
-- + フォロー/投稿カウント更新トリガー
-- + RLSポリシー拡張（他ユーザーの公開プロフィール閲覧）
-- =============================================================

-- SNS関連カラム追加（冪等: IF NOT EXISTS は ALTER TABLE ADD COLUMN では使えないため DO ブロック使用）
DO $$
BEGIN
  -- プロフィール公開範囲
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'visibility') THEN
    ALTER TABLE profiles ADD COLUMN visibility text NOT NULL DEFAULT 'public'
      CHECK (visibility IN ('public', 'followers_only', 'private'));
  END IF;

  -- 非正規化カウンタ
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'followers_count') THEN
    ALTER TABLE profiles ADD COLUMN followers_count integer NOT NULL DEFAULT 0 CHECK (followers_count >= 0);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'following_count') THEN
    ALTER TABLE profiles ADD COLUMN following_count integer NOT NULL DEFAULT 0 CHECK (following_count >= 0);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'posts_count') THEN
    ALTER TABLE profiles ADD COLUMN posts_count integer NOT NULL DEFAULT 0 CHECK (posts_count >= 0);
  END IF;

  -- 外部リンク
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'github_url') THEN
    ALTER TABLE profiles ADD COLUMN github_url text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'x_url') THEN
    ALTER TABLE profiles ADD COLUMN x_url text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'website_url') THEN
    ALTER TABLE profiles ADD COLUMN website_url text;
  END IF;
END
$$;

-- コメント
COMMENT ON COLUMN profiles.visibility       IS 'プロフィール公開範囲: public / followers_only / private';
COMMENT ON COLUMN profiles.followers_count   IS 'フォロワー数（非正規化）';
COMMENT ON COLUMN profiles.following_count   IS 'フォロー数（非正規化）';
COMMENT ON COLUMN profiles.posts_count       IS '投稿数（非正規化）';
COMMENT ON COLUMN profiles.github_url        IS 'GitHub プロフィールURL';
COMMENT ON COLUMN profiles.x_url            IS 'X (Twitter) プロフィールURL';
COMMENT ON COLUMN profiles.website_url       IS '個人サイトURL';

-- =============================================================
-- フォロー時のカウント更新トリガー
-- =============================================================
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- フォローする側の following_count +1
    UPDATE profiles SET following_count = following_count + 1
    WHERE id = NEW.follower_id;
    -- フォローされる側の followers_count +1
    UPDATE profiles SET followers_count = followers_count + 1
    WHERE id = NEW.following_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- フォローする側の following_count -1
    UPDATE profiles SET following_count = GREATEST(following_count - 1, 0)
    WHERE id = OLD.follower_id;
    -- フォローされる側の followers_count -1
    UPDATE profiles SET followers_count = GREATEST(followers_count - 1, 0)
    WHERE id = OLD.following_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_follow_counts ON follows;
CREATE TRIGGER trg_follow_counts
  AFTER INSERT OR DELETE ON follows
  FOR EACH ROW
  EXECUTE FUNCTION update_follow_counts();

-- =============================================================
-- 投稿時のカウント更新トリガー
-- =============================================================
CREATE OR REPLACE FUNCTION update_posts_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE profiles SET posts_count = posts_count + 1
    WHERE id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE profiles SET posts_count = GREATEST(posts_count - 1, 0)
    WHERE id = OLD.user_id;
    RETURN OLD;
  END IF;
  -- 論理削除の場合（is_deleted が false → true）
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = false AND NEW.is_deleted = true THEN
    UPDATE profiles SET posts_count = GREATEST(posts_count - 1, 0)
    WHERE id = NEW.user_id;
  END IF;
  -- 論理削除の復元（is_deleted が true → false）
  IF TG_OP = 'UPDATE' AND OLD.is_deleted = true AND NEW.is_deleted = false THEN
    UPDATE profiles SET posts_count = posts_count + 1
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_posts_count ON posts;
CREATE TRIGGER trg_posts_count
  AFTER INSERT OR DELETE OR UPDATE OF is_deleted ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_posts_count();

-- =============================================================
-- profiles の RLS ポリシー拡張
-- SNS機能のために他ユーザーの公開プロフィールを閲覧可能にする
-- =============================================================

-- 既存の「自分のみ閲覧」ポリシーを削除して、SNS対応版に置き換え
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;

-- 新しいSELECTポリシー:
-- 1. 自分のプロフィールは常に閲覧可
-- 2. publicプロフィールは全認証ユーザーが閲覧可（ブロック除外）
-- 3. followers_onlyプロフィールはフォロワーが閲覧可（ブロック除外）
DROP POLICY IF EXISTS "profiles_select_sns" ON profiles;
CREATE POLICY "profiles_select_sns" ON profiles
  FOR SELECT
  TO authenticated
  USING (
    -- 自分のプロフィール
    id = (select auth.uid())
    -- 公開プロフィール（ブロック除外）
    OR (
      visibility = 'public'
      AND NOT EXISTS (
        SELECT 1 FROM blocks
        WHERE (blocker_id = (select auth.uid()) AND blocked_id = profiles.id)
           OR (blocker_id = profiles.id AND blocked_id = (select auth.uid()))
      )
    )
    -- フォロワー限定プロフィール（フォロワーのみ、ブロック除外）
    OR (
      visibility = 'followers_only'
      AND EXISTS (
        SELECT 1 FROM follows
        WHERE follower_id = (select auth.uid())
          AND following_id = profiles.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM blocks
        WHERE (blocker_id = (select auth.uid()) AND blocked_id = profiles.id)
           OR (blocker_id = profiles.id AND blocked_id = (select auth.uid()))
      )
    )
  );

-- インデックス（プロフィール検索用）
CREATE INDEX IF NOT EXISTS idx_profiles_visibility
  ON profiles (visibility)
  WHERE visibility = 'public';

-- =============================================================
-- posts の RLS ポリシー（blocks/follows テーブル作成後に適用）
-- =============================================================

-- SELECT: 公開投稿 + followers_only（フォロワーのみ） + 自分の投稿
-- ブロック関係にあるユーザーの投稿は非表示
DROP POLICY IF EXISTS "posts_select" ON posts;
CREATE POLICY "posts_select" ON posts
  FOR SELECT
  TO authenticated
  USING (
    is_deleted = false
    AND (
      -- 自分の投稿は常に見える
      user_id = (select auth.uid())
      -- public は全員に見える（ブロック除外）
      OR (
        visibility = 'public'
        AND NOT EXISTS (
          SELECT 1 FROM blocks
          WHERE (blocker_id = (select auth.uid()) AND blocked_id = posts.user_id)
             OR (blocker_id = posts.user_id AND blocked_id = (select auth.uid()))
        )
      )
      -- followers_only はフォロワーに見える（ブロック除外）
      OR (
        visibility = 'followers_only'
        AND EXISTS (
          SELECT 1 FROM follows
          WHERE follower_id = (select auth.uid())
            AND following_id = posts.user_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM blocks
          WHERE (blocker_id = (select auth.uid()) AND blocked_id = posts.user_id)
             OR (blocker_id = posts.user_id AND blocked_id = (select auth.uid()))
        )
      )
    )
  );

-- INSERT: 自分の投稿のみ
DROP POLICY IF EXISTS "posts_insert" ON posts;
CREATE POLICY "posts_insert" ON posts
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- UPDATE: 自分の投稿 かつ 作成から24時間以内
DROP POLICY IF EXISTS "posts_update" ON posts;
CREATE POLICY "posts_update" ON posts
  FOR UPDATE
  TO authenticated
  USING (
    user_id = (select auth.uid())
    AND created_at > now() - interval '24 hours'
  )
  WITH CHECK (
    user_id = (select auth.uid())
  );

-- DELETE: 論理削除のみ（is_deleted = true に UPDATE する運用）
-- 物理DELETEは禁止（service_roleのみ）
DROP POLICY IF EXISTS "posts_delete" ON posts;
CREATE POLICY "posts_delete" ON posts
  FOR DELETE
  TO authenticated
  USING (false);  -- ユーザーによる物理削除は禁止
