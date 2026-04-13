-- User device tokens for APNs push notifications
--
-- ## 責務
-- iOS アプリから送信された APNs device token を保存して、
-- 通知送信時に Edge Function からこのテーブルを引くことで device を特定する。
--
-- ## RLS
-- ユーザーは自分の token のみ read/insert/update/delete 可能 (auth.uid() = user_id)。
-- service_role は通知送信のため全 token を読む。

CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android', 'web')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    -- 同一 user の同一 device の重複を避ける。
    -- APNs token は端末 / アプリ reinstall で変わるため user_id + token UNIQUE で十分。
    UNIQUE(user_id, token)
);

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION public.handle_user_device_tokens_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER user_device_tokens_set_updated_at
    BEFORE UPDATE ON public.user_device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_device_tokens_updated_at();

-- Index for lookup by user_id (notification sender では user_id でクエリ)
CREATE INDEX IF NOT EXISTS user_device_tokens_user_id_idx
    ON public.user_device_tokens(user_id);

-- RLS
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の token のみアクセス可能
CREATE POLICY "Users can read their own device tokens"
    ON public.user_device_tokens
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own device tokens"
    ON public.user_device_tokens
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own device tokens"
    ON public.user_device_tokens
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own device tokens"
    ON public.user_device_tokens
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

COMMENT ON TABLE public.user_device_tokens IS 'APNs/FCM device tokens for push notifications. Auth users can only access their own tokens.';
