-- ============================================================
-- comments_select RLSにブロック関係を考慮したフィルタを追加
-- blocksテーブルが存在する場合のみ適用
-- ============================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'blocks') THEN
        -- 既存ポリシーを削除して再作成
        DROP POLICY IF EXISTS "comments_select" ON public.comments;

        CREATE POLICY "comments_select" ON public.comments
            FOR SELECT TO authenticated
            USING (
                -- 自分がブロックしたユーザーのコメントは非表示
                NOT EXISTS (
                    SELECT 1 FROM public.blocks
                    WHERE blocks.blocker_id = auth.uid()
                      AND blocks.blocked_id = comments.user_id
                )
                AND
                -- 自分をブロックしたユーザーのコメントも非表示
                NOT EXISTS (
                    SELECT 1 FROM public.blocks
                    WHERE blocks.blocker_id = comments.user_id
                      AND blocks.blocked_id = auth.uid()
                )
            );
    END IF;
END $$;
