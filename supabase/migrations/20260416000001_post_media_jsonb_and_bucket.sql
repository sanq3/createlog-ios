-- Post media: schema upgrade to jsonb + Supabase Storage bucket for client-uploaded images.
--
-- ## 設計思想 (3 phase 移行対応、schema は全 phase 共通)
-- Phase 1 (0-50 user, 今): Supabase Free + client 側で 2 サイズ生成 (thumb 480px + full 1920px)
-- Phase 2 (50-10K user): Cloudflare R2 に移行 (Egress 無料)、URL host 差替のみ、schema 不変
-- Phase 3 (収益化後): Smart CDN / Cloudflare Images で on-the-fly dynamic resize (業界標準: Instagram/Twitter/Bluesky)
--   `thumb_url` を null にして client 側が `transformURL(url, width: 480)` fallback するだけで動的切替
--
-- ## JSON 構造
-- ```json
-- posts.media_urls = [
--   {"url": "https://.../full.jpg", "thumb_url": "https://.../thumb.jpg", "width": 2048, "height": 1536},
--   ...
-- ]
-- ```
--
-- ## 既存データ
-- MVP 段階で既存 posts データはゼロ前提 (TestFlight 未配布)。旧 text[] を drop & recreate する。

-- 1. posts.media_urls を jsonb に作り直し
ALTER TABLE public.posts DROP COLUMN IF EXISTS media_urls;
ALTER TABLE public.posts ADD COLUMN media_urls jsonb NOT NULL DEFAULT '[]'::jsonb;
COMMENT ON COLUMN public.posts.media_urls IS
  '投稿の画像配列。Phase 1 の client 生成 2 サイズは thumb_url を持つ。Phase 3 で CDN 動的生成に移行後は thumb_url null になる。構造: [{"url","thumb_url","width","height"}]';

-- 2. post-media bucket 作成 (avatars とは別 bucket、lifecycle 分離)
INSERT INTO storage.buckets (id, name, public)
VALUES ('post-media', 'post-media', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage RLS policies (post-media bucket 用)
-- SELECT は全公開 (public bucket なので読める)
-- INSERT / DELETE は本人のフォルダ (`{uuidLower}/...`) のみ
-- 注意: `uuidString.lowercased()` で client 側 path を作る (Postgres の uuid::text は lowercase 出力)。
--       これを忘れるとアップロードが 403 で全滅する (avatars bucket で発生した過去 bug 参照)。

CREATE POLICY "post_media_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post-media');

CREATE POLICY "post_media_own_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'post-media'
    AND (storage.foldername(name))[1] = ((SELECT auth.uid())::text)
  );

CREATE POLICY "post_media_own_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'post-media'
    AND (storage.foldername(name))[1] = ((SELECT auth.uid())::text)
  );

CREATE POLICY "post_media_own_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'post-media'
    AND (storage.foldername(name))[1] = ((SELECT auth.uid())::text)
  );
