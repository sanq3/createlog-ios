-- Tighten comparisons_cache RLS so it is not world-readable.

-- Ensure RLS enabled
ALTER TABLE comparisons_cache ENABLE ROW LEVEL SECURITY;

-- Remove broad read access
DROP POLICY IF EXISTS "All authenticated users can view cache" ON comparisons_cache;

-- Allow only service role to read/write cache rows
CREATE POLICY "Service role can read comparisons cache"
  ON comparisons_cache FOR SELECT
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role can insert comparisons cache"
  ON comparisons_cache FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role can update comparisons cache"
  ON comparisons_cache FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role can delete comparisons cache"
  ON comparisons_cache FOR DELETE
  USING (auth.role() = 'service_role');
