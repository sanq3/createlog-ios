-- レビュー交換: reviews テーブル作成
-- 実際のレビュー内容を管理

CREATE TABLE IF NOT EXISTS reviews (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  review_request_id uuid        NOT NULL REFERENCES review_requests(id) ON DELETE CASCADE,
  app_id            uuid        NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  reviewer_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating            integer     NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title             text        NOT NULL,
  body              text        NOT NULL,
  pros              text[],                -- 良い点
  cons              text[],                -- 改善点
  status            text        NOT NULL DEFAULT 'draft'
                                CHECK (status IN ('draft', 'submitted', 'published')),
  submitted_at      timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- 1つのレビューリクエストにつき1人1レビュー
CREATE UNIQUE INDEX idx_reviews_unique_per_request
  ON reviews(review_request_id, reviewer_id);

CREATE INDEX idx_reviews_app_id ON reviews(app_id);
CREATE INDEX idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX idx_reviews_review_request_id ON reviews(review_request_id);
CREATE INDEX idx_reviews_status ON reviews(status);
CREATE INDEX idx_reviews_rating ON reviews(rating);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_reviews_updated_at
  BEFORE UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_reviews_updated_at();

-- レビュー公開時にアプリの平均評価と件数を更新するトリガー
CREATE OR REPLACE FUNCTION update_app_rating_on_review()
RETURNS TRIGGER AS $$
BEGIN
  -- 新規公開または公開ステータスへの変更時
  IF NEW.status = 'published' AND (TG_OP = 'INSERT' OR OLD.status <> 'published') THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      )
    WHERE id = NEW.app_id;
  END IF;

  -- 公開から非公開への変更時
  IF TG_OP = 'UPDATE' AND OLD.status = 'published' AND NEW.status <> 'published' THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = NEW.app_id AND status = 'published'
      )
    WHERE id = NEW.app_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_app_rating
  AFTER INSERT OR UPDATE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_app_rating_on_review();

-- 削除時にも評価を再計算
CREATE OR REPLACE FUNCTION update_app_rating_on_review_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status = 'published' THEN
    UPDATE apps SET
      avg_rating = (
        SELECT COALESCE(AVG(rating)::decimal(3,2), 0)
        FROM reviews
        WHERE app_id = OLD.app_id AND status = 'published'
      ),
      review_count = (
        SELECT COUNT(*)
        FROM reviews
        WHERE app_id = OLD.app_id AND status = 'published'
      )
    WHERE id = OLD.app_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_app_rating_on_delete
  AFTER DELETE ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_app_rating_on_review_delete();

-- RLS有効化
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- 公開レビューは全認証ユーザーが閲覧可能、自分のレビューはステータス問わず閲覧可能
CREATE POLICY "Published reviews are viewable, own reviews always viewable"
  ON reviews FOR SELECT
  USING (
    status = 'published'
    OR reviewer_id = (SELECT auth.uid())
    -- レビューリクエスト作成者もレビューを閲覧可能
    OR EXISTS (
      SELECT 1 FROM review_requests
      WHERE review_requests.id = reviews.review_request_id
        AND review_requests.requester_id = (SELECT auth.uid())
    )
  );

-- 自分のレビューのみ作成可能（自分のアプリへの自己レビューは不可）
CREATE POLICY "Users can insert reviews for others apps"
  ON reviews FOR INSERT
  WITH CHECK (
    reviewer_id = (SELECT auth.uid())
    AND NOT EXISTS (
      SELECT 1 FROM apps
      WHERE apps.id = reviews.app_id
        AND apps.user_id = (SELECT auth.uid())
    )
  );

-- 自分のレビューのみ更新可能（submittedまで）
CREATE POLICY "Users can update own draft reviews"
  ON reviews FOR UPDATE
  USING (
    reviewer_id = (SELECT auth.uid())
    AND status IN ('draft', 'submitted')
  );

-- 自分のドラフトレビューのみ削除可能
CREATE POLICY "Users can delete own draft reviews"
  ON reviews FOR DELETE
  USING (
    reviewer_id = (SELECT auth.uid())
    AND status = 'draft'
  );
