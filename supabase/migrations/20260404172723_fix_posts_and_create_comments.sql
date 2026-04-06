-- ============================================================
-- Fix posts table (v2-design.md Critical #1)
-- Standardize column names and ensure consistency
-- ============================================================

-- Ensure likes_count column exists (standardize from like_count if present)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'like_count'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'likes_count'
    ) THEN
        ALTER TABLE public.posts RENAME COLUMN like_count TO likes_count;
    END IF;
END $$;

-- Add missing columns to posts if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'reposts_count'
    ) THEN
        ALTER TABLE public.posts ADD COLUMN reposts_count integer NOT NULL DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'comments_count'
    ) THEN
        ALTER TABLE public.posts ADD COLUMN comments_count integer NOT NULL DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'media_urls'
    ) THEN
        ALTER TABLE public.posts ADD COLUMN media_urls jsonb DEFAULT '[]'::jsonb;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'posts' AND column_name = 'visibility'
    ) THEN
        ALTER TABLE public.posts ADD COLUMN visibility text NOT NULL DEFAULT 'public';
    END IF;
END $$;

-- ============================================================
-- Create comments table (v2-design.md Critical #2)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content text NOT NULL,
    parent_comment_id uuid REFERENCES public.comments(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments(post_id, created_at);

-- RLS
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- SELECT: public posts comments are visible to all authenticated users
DROP POLICY IF EXISTS "comments_select" ON public.comments;
CREATE POLICY "comments_select" ON public.comments
    FOR SELECT TO authenticated
    USING (true);

-- INSERT: authenticated users can comment
DROP POLICY IF EXISTS "comments_insert" ON public.comments;
CREATE POLICY "comments_insert" ON public.comments
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- DELETE: only own comments
DROP POLICY IF EXISTS "comments_delete" ON public.comments;
CREATE POLICY "comments_delete" ON public.comments
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- Trigger: auto-update comments_count on posts
CREATE OR REPLACE FUNCTION public.update_post_comments_count()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_comments_count ON public.comments;
CREATE TRIGGER trg_update_comments_count
    AFTER INSERT OR DELETE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.update_post_comments_count();

-- ============================================================
-- Extend notification types (v2-design.md Critical #3)
-- ============================================================

-- Drop existing CHECK constraint on type if it exists, then re-add with all types
DO $$
DECLARE
    constraint_name text;
BEGIN
    SELECT conname INTO constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.notifications'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%';

    IF constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.notifications DROP CONSTRAINT ' || constraint_name;
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL; -- notifications table doesn't exist yet
END $$;

-- Add extended CHECK constraint (if notifications table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        ALTER TABLE public.notifications
            ADD CONSTRAINT notifications_type_check
            CHECK (type IN ('like', 'follow', 'comment', 'mention', 'repost', 'quote', 'system'));
    END IF;
END $$;

-- ============================================================
-- Add handle column to profiles if missing
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'handle'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN handle text UNIQUE;
        CREATE INDEX IF NOT EXISTS idx_profiles_handle ON public.profiles(handle);
    END IF;
END $$;
