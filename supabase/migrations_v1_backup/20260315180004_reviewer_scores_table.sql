-- レビュー交換: reviewer_scores テーブル作成
-- レビュアーの信頼性スコアとペナルティを管理

CREATE TABLE IF NOT EXISTS reviewer_scores (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_reviews         integer     NOT NULL DEFAULT 0,
  completed_reviews     integer     NOT NULL DEFAULT 0,
  avg_review_quality    decimal(3,2) DEFAULT 0,        -- レビュー品質の平均評価（1-5）
  reliability_score     decimal(5,2) NOT NULL DEFAULT 100.00,  -- 信頼性スコア（0-100）
  penalties_count       integer     NOT NULL DEFAULT 0, -- ペナルティ累計回数
  last_penalty_at       timestamptz,                    -- 最後のペナルティ日時
  streak_completed      integer     NOT NULL DEFAULT 0, -- 連続完了数
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- ユーザーごとに1レコード
CREATE UNIQUE INDEX idx_reviewer_scores_user_id ON reviewer_scores(user_id);
CREATE INDEX idx_reviewer_scores_reliability ON reviewer_scores(reliability_score DESC);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_reviewer_scores_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reviewer_scores_updated_at
  BEFORE UPDATE ON reviewer_scores
  FOR EACH ROW
  EXECUTE FUNCTION update_reviewer_scores_updated_at();

-- RLS有効化
ALTER TABLE reviewer_scores ENABLE ROW LEVEL SECURITY;

-- 全認証ユーザーがスコアを閲覧可能（レビュアー選択の参考情報）
CREATE POLICY "Reviewer scores are viewable by authenticated users"
  ON reviewer_scores FOR SELECT
  USING ((SELECT auth.uid()) IS NOT NULL);

-- 初回レコードは自分のもののみ作成可能
CREATE POLICY "Users can insert own reviewer score"
  ON reviewer_scores FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));

-- 自分のスコアはservice_roleのみ更新可能（不正防止）
-- ユーザー自身による直接更新は不可。Edge Function経由で更新する
CREATE POLICY "Only service role can update reviewer scores"
  ON reviewer_scores FOR UPDATE
  USING (false);
