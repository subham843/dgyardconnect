-- Anon can read active calculator families so child-table RLS (attributes, option
-- paths, question groups) that EXISTS-check calculator_families works publicly.
-- Without this, public calculator only got template questions — path follow-ups
-- never loaded and stayed hidden (default_visibility=false, no show_when).

DROP POLICY IF EXISTS "public_read_calculator_families" ON calculator_families;
CREATE POLICY "public_read_calculator_families" ON calculator_families
  FOR SELECT TO anon, authenticated
  USING (is_active = true);

COMMENT ON POLICY "public_read_calculator_families" ON calculator_families IS
  'Public calculator + nested RLS for family attributes / option paths / groups.';