-- =============================================================
-- Phase 1.1: blocks テーブル作成
-- ユーザーブロック機能
-- =============================================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS blocks (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id  uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id  uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),

  -- 自分自身のブロック禁止
  CONSTRAINT chk_no_self_block CHECK (blocker_id != blocked_id),
  -- 同一ペアの重複禁止
  CONSTRAINT uq_blocks_pair UNIQUE (blocker_id, blocked_id)
);

-- コメント
COMMENT ON TABLE  blocks             IS 'ユーザーブロック';
COMMENT ON COLUMN blocks.blocker_id  IS 'ブロックした側のユーザーID';
COMMENT ON COLUMN blocks.blocked_id  IS 'ブロックされた側のユーザーID';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_blocks_blocker
  ON blocks (blocker_id);

CREATE INDEX IF NOT EXISTS idx_blocks_blocked
  ON blocks (blocked_id);

-- =============================================================
-- ブロック時にフォロー関係を自動解除するトリガー
-- =============================================================
CREATE OR REPLACE FUNCTION remove_follows_on_block()
RETURNS TRIGGER AS $$
BEGIN
  -- 双方向のフォロー関係を解除
  DELETE FROM follows
  WHERE (follower_id = NEW.blocker_id AND following_id = NEW.blocked_id)
     OR (follower_id = NEW.blocked_id AND following_id = NEW.blocker_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_remove_follows_on_block ON blocks;
CREATE TRIGGER trg_remove_follows_on_block
  AFTER INSERT ON blocks
  FOR EACH ROW
  EXECUTE FUNCTION remove_follows_on_block();

-- =============================================================
-- RLS ポリシー
-- =============================================================
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

-- SELECT: 自分のブロックリストのみ閲覧可能
DROP POLICY IF EXISTS "blocks_select" ON blocks;
CREATE POLICY "blocks_select" ON blocks
  FOR SELECT
  TO authenticated
  USING (blocker_id = (select auth.uid()));

-- INSERT: 自分がブロックする側のみ
DROP POLICY IF EXISTS "blocks_insert" ON blocks;
CREATE POLICY "blocks_insert" ON blocks
  FOR INSERT
  TO authenticated
  WITH CHECK (blocker_id = (select auth.uid()));

-- UPDATE: ブロックの更新は不要
-- ポリシーなし = 更新禁止

-- DELETE: 自分のブロックのみ解除可能
DROP POLICY IF EXISTS "blocks_delete" ON blocks;
CREATE POLICY "blocks_delete" ON blocks
  FOR DELETE
  TO authenticated
  USING (blocker_id = (select auth.uid()));
