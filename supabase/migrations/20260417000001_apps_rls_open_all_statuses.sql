-- Discover コンセプト刷新: マイプロダクトは開発中 / 公開中 / 停止 全 status を他人にも見せる。
-- 宣伝目的 (user 方針 2026-04-17)。他人に draft / archived も見える。
--
-- 影響範囲:
-- - Discover フィードに全 status の apps が流れる
-- - 他人の Profile からも全 status が見える (Profile 側 UI で status badge 表示済み)
-- - review_requests / reviews は apps が見える前提なのでそのまま通る

BEGIN;

DROP POLICY IF EXISTS "Published apps are viewable by authenticated users" ON public.apps;

CREATE POLICY "Apps are viewable by authenticated users"
    ON public.apps
    FOR SELECT
    TO authenticated
    USING (true);

COMMIT;
