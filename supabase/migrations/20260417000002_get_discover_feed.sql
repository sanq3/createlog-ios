-- Discover 専用 RPC。「読む意味のある投稿」だけを返す:
--   (media あり) OR (content 200 文字以上) OR (リプライ 1 件以上)
-- 短文 text only post はタイムライン (Home) のみで流れ、Discover には出ない。
--
-- profiles を LEFT JOIN で作者 basic (display_name/handle/avatar_url) も flat に返す。
-- PostDTO.init(from:) は nested author 優先、flat `author_*` フィールドを fallback で decode する設計なので、
-- そのまま decode 可能。
--
-- cursor_created_at はページング用 (最古の created_at より古いものを返す)、null なら初回。

CREATE OR REPLACE FUNCTION public.get_discover_feed(
    page_limit integer,
    cursor_created_at timestamptz DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    user_id uuid,
    content text,
    media_urls jsonb,
    likes_count integer,
    reposts_count integer,
    comments_count integer,
    visibility text,
    created_at timestamptz,
    updated_at timestamptz,
    author_display_name text,
    author_handle text,
    author_avatar_url text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
    SELECT
        p.id,
        p.user_id,
        p.content,
        p.media_urls,
        p.likes_count,
        p.reposts_count,
        p.comments_count,
        p.visibility,
        p.created_at,
        p.updated_at,
        pr.display_name AS author_display_name,
        pr.handle AS author_handle,
        pr.avatar_url AS author_avatar_url
    FROM public.posts p
    LEFT JOIN public.profiles pr ON pr.id = p.user_id
    WHERE p.visibility = 'public'
      AND (
          jsonb_array_length(COALESCE(p.media_urls, '[]'::jsonb)) > 0
          OR char_length(COALESCE(p.content, '')) >= 200
          OR COALESCE(p.comments_count, 0) >= 1
      )
      AND (cursor_created_at IS NULL OR p.created_at < cursor_created_at)
    ORDER BY p.created_at DESC
    LIMIT page_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_discover_feed(integer, timestamptz) TO authenticated;
