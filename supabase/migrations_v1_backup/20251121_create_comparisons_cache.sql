-- comparisons_cacheテーブルの作成
CREATE TABLE IF NOT EXISTS comparisons_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key TEXT NOT NULL,
  filters JSONB DEFAULT '{}'::jsonb,
  data JSONB NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- cache_keyにユニーク制約を追加（upsert用）
CREATE UNIQUE INDEX IF NOT EXISTS comparisons_cache_key_idx ON comparisons_cache (cache_key);

-- RLSの有効化（既存のポリシー適用のため）
ALTER TABLE comparisons_cache ENABLE ROW LEVEL SECURITY;

-- 全ユーザーがキャッシュを読み取り可能（統計データのため）
-- 既存のポリシーファイルで定義されている可能性がありますが、念のため確認
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'comparisons_cache' AND policyname = 'All authenticated users can view cache'
    ) THEN
        CREATE POLICY "All authenticated users can view cache" ON comparisons_cache
          FOR SELECT USING (auth.role() = 'authenticated');
    END IF;
END
$$;
