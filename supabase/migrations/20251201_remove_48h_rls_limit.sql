-- SEC-M01: RLS 48時間制限をアプリ層へ移動
-- 48時間制限はアプリ層（logStore.ts）で検証するため、RLSからは削除

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can update their recent logs" ON logs;

-- 新しいポリシーを作成（48時間制限なし）
CREATE POLICY "Users can update their own logs"
  ON logs FOR UPDATE
  USING (auth.uid() = user_id);
