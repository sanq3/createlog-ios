-- heartbeats テーブル: エディタ/デスクトップからの自動トラッキングデータ
-- Phase 4: 自動トラッキング機能

CREATE TABLE IF NOT EXISTS heartbeats (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source      text        NOT NULL CHECK (source IN ('vscode', 'claude_code', 'codex', 'desktop')),
  project_name text       NOT NULL DEFAULT '',
  file_path   text        NOT NULL DEFAULT '',
  language    text        NOT NULL DEFAULT '',
  category_id uuid        REFERENCES categories(id) ON DELETE SET NULL,
  timestamp   timestamptz NOT NULL DEFAULT now(),
  metadata    jsonb       NOT NULL DEFAULT '{}',
  is_processed boolean    NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- コメント
COMMENT ON TABLE  heartbeats IS 'エディタ・デスクトップアプリからのheartbeatイベント';
COMMENT ON COLUMN heartbeats.source IS 'イベント送信元 (vscode, claude_code, codex, desktop)';
COMMENT ON COLUMN heartbeats.is_processed IS 'aggregate-heartbeats で集約済みか';

-- インデックス
CREATE INDEX idx_heartbeats_user_timestamp
  ON heartbeats (user_id, timestamp DESC);

CREATE INDEX idx_heartbeats_unprocessed
  ON heartbeats (user_id, is_processed, timestamp)
  WHERE is_processed = false;

-- 90日超の古いデータ自動削除用インデックス
CREATE INDEX idx_heartbeats_created_at
  ON heartbeats (created_at);

-- RLS 有効化
ALTER TABLE heartbeats ENABLE ROW LEVEL SECURITY;

-- ポリシー: 自分のデータのみ
CREATE POLICY "Users can view own heartbeats"
  ON heartbeats FOR SELECT
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert own heartbeats"
  ON heartbeats FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete own heartbeats"
  ON heartbeats FOR DELETE
  USING ((select auth.uid()) = user_id);

-- service_role はバッチ処理で UPDATE が必要
-- (RLS は service_role では自動バイパスされるため明示ポリシー不要)

-- 90日超の古いheartbeatを削除するcronジョブ（pg_cron拡張が必要）
-- Supabase Pro以上で利用可能。Free planではEdge Functionで代替可能
-- SELECT cron.schedule(
--   'cleanup-old-heartbeats',
--   '0 3 * * *',  -- 毎日 03:00 UTC
--   $$DELETE FROM heartbeats WHERE created_at < now() - interval '90 days'$$
-- );
