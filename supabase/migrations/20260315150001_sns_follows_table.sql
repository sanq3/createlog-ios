-- =============================================================
-- Phase 1.1: follows テーブル作成
-- Twitter型フォロー（承認不要）
-- =============================================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS follows (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id   uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id  uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),

  -- 自分自身のフォロー禁止
  CONSTRAINT chk_no_self_follow CHECK (follower_id != following_id),
  -- 同一ペアの重複禁止
  CONSTRAINT uq_follows_pair UNIQUE (follower_id, following_id)
);

-- コメント
COMMENT ON TABLE  follows               IS 'フォロー関係（Twitter型）';
COMMENT ON COLUMN follows.follower_id    IS 'フォローする側のユーザーID';
COMMENT ON COLUMN follows.following_id   IS 'フォローされる側のユーザーID';

-- インデックス（フォロワー一覧・フォロー一覧の取得用）
CREATE INDEX IF NOT EXISTS idx_follows_follower
  ON follows (follower_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_follows_following
  ON follows (following_id, created_at DESC);

-- =============================================================
-- RLS ポリシー
-- =============================================================
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- SELECT: 自分が関係するフォローのみ閲覧可能
DROP POLICY IF EXISTS "follows_select" ON follows;
CREATE POLICY "follows_select" ON follows
  FOR SELECT
  TO authenticated
  USING (
    follower_id = (select auth.uid())
    OR following_id = (select auth.uid())
  );

-- INSERT: 自分がフォローする側のみ
DROP POLICY IF EXISTS "follows_insert" ON follows;
CREATE POLICY "follows_insert" ON follows
  FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = (select auth.uid()));

-- UPDATE: フォロー関係の更新は不要（削除→再作成）
-- ポリシーなし = 更新禁止

-- DELETE: 自分がフォローしたものだけ解除可能
DROP POLICY IF EXISTS "follows_delete" ON follows;
CREATE POLICY "follows_delete" ON follows
  FOR DELETE
  TO authenticated
  USING (follower_id = (select auth.uid()));
