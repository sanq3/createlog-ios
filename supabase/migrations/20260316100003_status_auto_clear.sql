-- Auto-clear stale profile status
-- Clears status when status_updated_at is older than 10 minutes

CREATE OR REPLACE FUNCTION clear_stale_profile_status()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE profiles
  SET
    current_status = NULL,
    status_type = NULL,
    status_project = NULL,
    status_started_at = NULL,
    status_updated_at = NULL
  WHERE status_type IS NOT NULL
    AND status_updated_at < NOW() - INTERVAL '10 minutes';
END;
$$;

-- Grant execute to service_role (for Edge Functions / cron)
GRANT EXECUTE ON FUNCTION clear_stale_profile_status() TO service_role;

COMMENT ON FUNCTION clear_stale_profile_status IS 'Clears profile status when status_updated_at is older than 10 minutes. Called by aggregate-heartbeats Edge Function or pg_cron.';

-- Optional: If pg_cron is available, schedule automatic cleanup every 5 minutes
-- Uncomment the following if pg_cron extension is enabled:
-- SELECT cron.schedule(
--   'clear-stale-status',
--   '*/5 * * * *',
--   $$ SELECT clear_stale_profile_status(); $$
-- );
