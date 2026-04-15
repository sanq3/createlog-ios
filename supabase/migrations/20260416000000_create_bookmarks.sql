-- Create bookmarks table for per-user post saving.
--
-- ## 設計
-- - `likes` テーブルと同形 (id/user_id/post_id/created_at、unique(user_id, post_id))
-- - RLS: **自分のブックマークのみ SELECT/INSERT/DELETE 可** (likes は select 全公開だが、
--   bookmark は X / Instagram 仕様で本人のみ閲覧可が標準なので select も自分に絞る)
-- - `posts.bookmarks_count` カラムは作らない (業界標準で投稿カードに bookmark 数は出さない)
-- - btree index on (user_id, created_at DESC) で自分のブックマーク一覧を高速取得
--
-- ## Reference
-- likes テーブル定義 (20260410152527_remote_baseline.sql L1434) と整合。

CREATE TABLE IF NOT EXISTS public.bookmarks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    post_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.bookmarks OWNER TO postgres;

COMMENT ON TABLE public.bookmarks IS '投稿のブックマーク (本人のみ閲覧可)';
COMMENT ON COLUMN public.bookmarks.user_id IS 'ブックマークしたユーザー';
COMMENT ON COLUMN public.bookmarks.post_id IS 'ブックマーク対象の投稿';

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT uq_bookmarks_user_post UNIQUE (user_id, post_id);

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_post_id_fkey
    FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

CREATE INDEX idx_bookmarks_user
    ON public.bookmarks USING btree (user_id, created_at DESC);

ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY bookmarks_select ON public.bookmarks
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

CREATE POLICY bookmarks_insert ON public.bookmarks
    FOR INSERT TO authenticated
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY bookmarks_delete ON public.bookmarks
    FOR DELETE TO authenticated
    USING (user_id = (SELECT auth.uid()));

GRANT ALL ON TABLE public.bookmarks TO anon;
GRANT ALL ON TABLE public.bookmarks TO authenticated;
GRANT ALL ON TABLE public.bookmarks TO service_role;
