-- Optimize user_device_tokens RLS policies for performance.
--
-- ## 何をしているか
-- 既存の RLS policy は `auth.uid() = user_id` を直書きしており、
-- Postgres は per-row で `auth.uid()` 関数を再評価していた。
-- Supabase 公式推奨の `(select auth.uid())` wrap に書き換えることで
-- initPlan cache が効き、1 statement で 1 回だけ評価される。
-- 大量 device tokens を扱う push sender 側のクエリ (全ユーザーの端末 fetch) で
-- 100x 以上の速度改善が期待できる。
--
-- ## Reference
-- https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv
-- https://github.com/orgs/supabase/discussions/14576
--
-- ## 追加対応
-- - token 単体での lookup インデックス追加 (token rotation / invalidation 用)
-- - policy を DROP → CREATE で idempotent に再作成

-- 1. 既存 policy を削除して再作成 (USING/WITH CHECK を optimized 版に)
DROP POLICY IF EXISTS "Users can read their own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can insert their own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can update their own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can delete their own device tokens" ON public.user_device_tokens;

CREATE POLICY "Users can read their own device tokens"
    ON public.user_device_tokens
    FOR SELECT
    TO authenticated
    USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own device tokens"
    ON public.user_device_tokens
    FOR INSERT
    TO authenticated
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update their own device tokens"
    ON public.user_device_tokens
    FOR UPDATE
    TO authenticated
    USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete their own device tokens"
    ON public.user_device_tokens
    FOR DELETE
    TO authenticated
    USING ((select auth.uid()) = user_id);

-- 2. token 単体インデックス (rotation / invalidation lookup)
CREATE INDEX IF NOT EXISTS user_device_tokens_token_idx
    ON public.user_device_tokens(token);

COMMENT ON INDEX public.user_device_tokens_token_idx IS 'Lookup by token for APNs invalidation / rotation flow.';
