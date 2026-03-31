-- logs.started_at に降順インデックスを追加
-- 理由: daily_stats トリガーや global_stats バッチなど
-- 全ユーザー集計で started_at >= fromDate の絞り込みが頻繁に発生するため
-- 既存の (user_id, started_at DESC) とは別に、user_id を含まない単独インデックスが必要

CREATE INDEX IF NOT EXISTS idx_logs_started_at
  ON public.logs (started_at DESC);
