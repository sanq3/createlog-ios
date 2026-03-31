-- レビュー交換: review_requests テーブル作成
-- ユーザーが自分のアプリに対するレビューを依頼するリクエスト

CREATE TABLE IF NOT EXISTS review_requests (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id          uuid        NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  requester_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title           text        NOT NULL,
  description     text,
  review_points   text[],                -- レビューしてほしいポイント（配列）
  status          text        NOT NULL DEFAULT 'open'
                              CHECK (status IN ('open', 'matched', 'in_progress', 'completed', 'cancelled')),
  matched_at      timestamptz,
  deadline        timestamptz,           -- レビュー期限
  max_reviewers   integer     NOT NULL DEFAULT 1,
  current_reviewers integer   NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- インデックス
CREATE INDEX idx_review_requests_app_id ON review_requests(app_id);
CREATE INDEX idx_review_requests_requester_id ON review_requests(requester_id);
CREATE INDEX idx_review_requests_status ON review_requests(status);
CREATE INDEX idx_review_requests_created_at ON review_requests(created_at DESC);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_review_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_review_requests_updated_at
  BEFORE UPDATE ON review_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_review_requests_updated_at();

-- RLS有効化
ALTER TABLE review_requests ENABLE ROW LEVEL SECURITY;

-- オープンなレビューリクエストは全認証ユーザーが閲覧可能
CREATE POLICY "Open review requests are viewable by authenticated users"
  ON review_requests FOR SELECT
  USING (
    status IN ('open', 'matched', 'in_progress', 'completed')
    OR requester_id = (SELECT auth.uid())
  );

-- 自分のレビューリクエストのみ作成可能
CREATE POLICY "Users can insert own review requests"
  ON review_requests FOR INSERT
  WITH CHECK (requester_id = (SELECT auth.uid()));

-- 自分のレビューリクエストのみ更新可能
CREATE POLICY "Users can update own review requests"
  ON review_requests FOR UPDATE
  USING (requester_id = (SELECT auth.uid()));

-- 自分のレビューリクエストのみ削除可能（openステータスのみ）
CREATE POLICY "Users can delete own open review requests"
  ON review_requests FOR DELETE
  USING (
    requester_id = (SELECT auth.uid())
    AND status = 'open'
  );
