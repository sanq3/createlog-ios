-- =============================================================
-- Phase 1.1: notifications テーブル作成
-- アプリ内通知（フォロー、いいね、レビュー等）
-- =============================================================

-- テーブル作成
CREATE TABLE IF NOT EXISTS notifications (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_id      uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  type          text        NOT NULL
                CHECK (type IN (
                  'follow', 'like', 'review_request',
                  'review_completed', 'milestone'
                )),
  post_id       uuid        REFERENCES posts(id) ON DELETE CASCADE,
  data          jsonb       DEFAULT '{}',
  is_read       boolean     NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- コメント
COMMENT ON TABLE  notifications            IS 'アプリ内通知';
COMMENT ON COLUMN notifications.user_id    IS '通知の受信者';
COMMENT ON COLUMN notifications.actor_id   IS '通知のトリガーとなったユーザー（NULLはシステム通知）';
COMMENT ON COLUMN notifications.type       IS '通知タイプ: follow / like / review_request / review_completed / milestone';
COMMENT ON COLUMN notifications.post_id    IS '関連する投稿（いいね通知等で使用）';
COMMENT ON COLUMN notifications.data       IS '追加データ（マイルストーン詳細等）';
COMMENT ON COLUMN notifications.is_read    IS '既読フラグ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, is_read, created_at DESC)
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications (user_id, created_at DESC);

-- =============================================================
-- RLS ポリシー
-- =============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: 自分の通知のみ
DROP POLICY IF EXISTS "notifications_select" ON notifications;
CREATE POLICY "notifications_select" ON notifications
  FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

-- INSERT: サーバー側（トリガー/Edge Function）から作成されるため
-- SECURITY DEFINER 関数経由。ユーザー直接INSERTも自分宛のみ許可
DROP POLICY IF EXISTS "notifications_insert" ON notifications;
CREATE POLICY "notifications_insert" ON notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- UPDATE: 自分の通知のみ（既読マーク用）
DROP POLICY IF EXISTS "notifications_update" ON notifications;
CREATE POLICY "notifications_update" ON notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- DELETE: 自分の通知のみ削除可能
DROP POLICY IF EXISTS "notifications_delete" ON notifications;
CREATE POLICY "notifications_delete" ON notifications
  FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));
