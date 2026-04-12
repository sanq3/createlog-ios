-- T7a/T7c realtime subscribe で DELETE イベント発火時、
-- Supabase Realtime は default で `oldRecord` に PK のみ返す。
-- REPLICA IDENTITY FULL 指定で全カラムを `oldRecord` に返すよう変更。
--
-- 対象 3 table (user 体感直結):
-- - notifications: 通知バッジ即時更新、delete で既読マーク取り消し等
-- - posts: 自分の post が他 device で削除 → feed 即反映 (multi-device の核)
-- - comments: 自分の comment が削除 → UI 即時撤回
--
-- WAL サイズが若干増えるが、対象 3 table は delete 頻度が低いため無視可能。
-- T7 realtime subscribe は v1.1 (T7d) で本格実装、ただし migration は先行適用。
--
-- team-lead decision: 2026-04-11
-- planner verification: baseline SQL 実コード確認済み、3 table すべて実在

ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.posts REPLICA IDENTITY FULL;
ALTER TABLE public.comments REPLICA IDENTITY FULL;
