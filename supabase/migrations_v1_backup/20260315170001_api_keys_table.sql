-- api_keys テーブル: VS Code拡張・デスクトップアプリ用のAPIキー管理
-- Phase 4: 自動トラッキング機能

CREATE TABLE IF NOT EXISTS api_keys (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text        NOT NULL DEFAULT 'Default',
  key_hash    text        NOT NULL,  -- SHA-256 ハッシュ
  key_prefix  text        NOT NULL,  -- 先頭8文字（表示用）
  last_used_at timestamptz,
  expires_at  timestamptz,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- コメント
COMMENT ON TABLE  api_keys IS 'エディタ拡張・デスクトップアプリの認証用APIキー';
COMMENT ON COLUMN api_keys.key_hash IS 'APIキーのSHA-256ハッシュ。平文は保存しない';
COMMENT ON COLUMN api_keys.key_prefix IS 'APIキーの先頭8文字。ユーザーがキーを識別するため';

-- インデックス
CREATE INDEX idx_api_keys_user_id
  ON api_keys (user_id);

CREATE INDEX idx_api_keys_key_hash
  ON api_keys (key_hash)
  WHERE is_active = true;

CREATE UNIQUE INDEX idx_api_keys_key_prefix_user
  ON api_keys (user_id, key_prefix);

-- RLS 有効化
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- ポリシー: 自分のキーのみ
CREATE POLICY "Users can view own api_keys"
  ON api_keys FOR SELECT
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert own api_keys"
  ON api_keys FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update own api_keys"
  ON api_keys FOR UPDATE
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete own api_keys"
  ON api_keys FOR DELETE
  USING ((select auth.uid()) = user_id);

-- updated_at 自動更新トリガー
CREATE TRIGGER update_api_keys_updated_at
  BEFORE UPDATE ON api_keys
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
