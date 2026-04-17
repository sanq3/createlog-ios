-- Discover 混合フィードの新着ソート用。user が編集画面で「更新を公開」を押すと
-- アプリ側でこのカラムを now() に更新 → Discover の上位に bump される。
-- 通常の編集 (typo 修正等) では更新しない運用。
--
-- 初期値: 既存行は created_at を複製、NOT NULL 化。新規 insert は default now()。

BEGIN;

ALTER TABLE public.apps
    ADD COLUMN IF NOT EXISTS last_bumped_at timestamptz;

UPDATE public.apps
SET last_bumped_at = created_at
WHERE last_bumped_at IS NULL;

ALTER TABLE public.apps
    ALTER COLUMN last_bumped_at SET NOT NULL,
    ALTER COLUMN last_bumped_at SET DEFAULT now();

-- Discover 新着順読み込み + cursor pagination 用 index
CREATE INDEX IF NOT EXISTS apps_last_bumped_at_idx
    ON public.apps (last_bumped_at DESC);

COMMIT;
