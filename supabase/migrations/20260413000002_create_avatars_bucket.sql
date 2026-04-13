-- Avatars storage bucket + RLS policies
--
-- ## 責務
-- ユーザーが自分のアバター画像を Supabase Storage にアップロードできる bucket を作る。
-- path は `{user_id}/{timestamp}.jpg` 形式 (iOS 側 SupabaseProfileRepository.uploadAvatar で決定)。
--
-- ## RLS
-- - 誰でも avatar は read 可能 (public: true、URL でシェア可能なため)
-- - ユーザーは自分の prefix 配下のみ upload/update/delete 可能 (auth.uid() = storage prefix)

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,  -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage RLS policies
-- 誰でも avatar の read は可能 (public bucket だが明示的に policy を書く)
DROP POLICY IF EXISTS "Anyone can read avatars" ON storage.objects;
CREATE POLICY "Anyone can read avatars"
    ON storage.objects
    FOR SELECT
    TO public
    USING (bucket_id = 'avatars');

-- 認証済みユーザーのみ自分の prefix 配下にアップロード可能
-- (storage.foldername(name) は path を '/' で分割した text[] を返す)
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- COMMENT は owner 権限不足で失敗するため省略。
