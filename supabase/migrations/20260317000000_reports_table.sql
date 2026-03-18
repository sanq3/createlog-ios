-- 通報テーブル
-- Purpose: UGCに対する通報機能（App Store Review Guidelines 1.2(b)要件）
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 通報対象（投稿 or ユーザー）
  target_type TEXT NOT NULL CHECK (target_type IN ('post', 'user', 'app', 'review')),
  target_id UUID NOT NULL,
  -- 通報理由
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'misinformation', 'other')),
  description TEXT, -- 詳細（任意）
  -- 処理状態
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の通報のみ作成可能
CREATE POLICY "Users can create reports" ON public.reports
  FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = reporter_id);

-- ユーザーは自分の通報のみ閲覧可能
CREATE POLICY "Users can view own reports" ON public.reports
  FOR SELECT TO authenticated
  USING ((select auth.uid()) = reporter_id);

-- インデックス
CREATE INDEX idx_reports_target ON public.reports (target_type, target_id);
CREATE INDEX idx_reports_status ON public.reports (status) WHERE status = 'pending';
CREATE INDEX idx_reports_reporter ON public.reports (reporter_id);
-- 重複通報防止用（同一ユーザーが同一対象を重複通報しないためのユニーク制約）
CREATE UNIQUE INDEX idx_reports_unique_per_reporter
  ON public.reports (reporter_id, target_type, target_id);

-- updated_atトリガー
CREATE TRIGGER set_reports_updated_at
  BEFORE UPDATE ON public.reports
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- rollback: DROP TABLE IF EXISTS public.reports CASCADE;
