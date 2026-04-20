-- likes / notifications の RLS にブロックフィルターを追加。
-- 既存 posts / comments / profiles と同じ双方向フィルター (自分がブロック OR 自分がブロックされた)。
-- 審査 blocker: ブロック相手の過去のいいね / 通知が残り続けて「ブロック = コンテンツ消去」の
-- 期待から外れる。X / Instagram 業界標準の挙動に揃える。

-- ============================================================
-- likes_select: ブロック相手のいいねを隠す
-- - 「いいね一覧」「isLiked 判定」「like count 計算」全てに影響
-- - ブロック相手のいいねは自分からは存在しないように見える
-- ============================================================

DROP POLICY IF EXISTS "likes_select" ON "public"."likes";

CREATE POLICY "likes_select" ON "public"."likes"
    FOR SELECT TO "authenticated"
    USING (
        NOT EXISTS (
            SELECT 1 FROM "public"."blocks"
            WHERE (
                ("blocks"."blocker_id" = (SELECT "auth"."uid"())
                 AND "blocks"."blocked_id" = "likes"."user_id")
                OR
                ("blocks"."blocker_id" = "likes"."user_id"
                 AND "blocks"."blocked_id" = (SELECT "auth"."uid"()))
            )
        )
    );

-- ============================================================
-- notifications_select: ブロック相手からの通知を隠す
-- - actor_id が NULL (system 通知) は常時表示
-- - actor_id が自分のブロック相手/ブロック元なら非表示
-- - 既存の user_id = auth.uid() 条件は維持
-- ============================================================

DROP POLICY IF EXISTS "notifications_select" ON "public"."notifications";

CREATE POLICY "notifications_select" ON "public"."notifications"
    FOR SELECT TO "authenticated"
    USING (
        "user_id" = (SELECT "auth"."uid"())
        AND (
            "actor_id" IS NULL
            OR NOT EXISTS (
                SELECT 1 FROM "public"."blocks"
                WHERE (
                    ("blocks"."blocker_id" = (SELECT "auth"."uid"())
                     AND "blocks"."blocked_id" = "notifications"."actor_id")
                    OR
                    ("blocks"."blocker_id" = "notifications"."actor_id"
                     AND "blocks"."blocked_id" = (SELECT "auth"."uid"()))
                )
            )
        )
    );
