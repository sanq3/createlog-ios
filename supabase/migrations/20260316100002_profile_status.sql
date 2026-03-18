-- Profile Status columns for realtime activity display
-- Shows when a user is actively working (timer or auto-tracking)

-- Add status columns to profiles table
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS current_status text,
  ADD COLUMN IF NOT EXISTS status_type text,
  ADD COLUMN IF NOT EXISTS status_project text,
  ADD COLUMN IF NOT EXISTS status_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS status_updated_at timestamptz;

-- Validate status_type values
ALTER TABLE profiles
  ADD CONSTRAINT profiles_status_type_check
  CHECK (status_type IS NULL OR status_type IN ('timer', 'auto_tracking', 'manual'));

-- RLS: users can only UPDATE their own status columns
-- (profiles table already has RLS enabled; add a policy for status updates)
CREATE POLICY "Users can update own status"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Enable Realtime for profiles table (idempotent via IF NOT EXISTS pattern)
-- Note: Supabase Realtime publication is managed at the table level.
-- If profiles is not yet in the realtime publication, add it:
DO $$
BEGIN
  -- Check if profiles is already in the supabase_realtime publication
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
  END IF;
END
$$;

-- Index for efficient status queries (find active users)
CREATE INDEX IF NOT EXISTS idx_profiles_status_type
  ON profiles (status_type)
  WHERE status_type IS NOT NULL;

COMMENT ON COLUMN profiles.current_status IS 'Human-readable status text, e.g. "React Nativeを開発中"';
COMMENT ON COLUMN profiles.status_type IS 'Activity source: timer | auto_tracking | manual';
COMMENT ON COLUMN profiles.status_project IS 'Project name from heartbeat or timer category';
COMMENT ON COLUMN profiles.status_started_at IS 'When the current activity session started';
COMMENT ON COLUMN profiles.status_updated_at IS 'Last heartbeat or status refresh timestamp';
