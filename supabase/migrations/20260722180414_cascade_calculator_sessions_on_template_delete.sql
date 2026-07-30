-- Allow family/template delete when calculator_sessions exist.
-- sessions were ON DELETE RESTRICT on template_id, blocking family cascade.

ALTER TABLE calculator_sessions
  DROP CONSTRAINT IF EXISTS calculator_sessions_template_id_fkey;

ALTER TABLE calculator_sessions
  ADD CONSTRAINT calculator_sessions_template_id_fkey
  FOREIGN KEY (template_id)
  REFERENCES calculator_templates (id)
  ON DELETE CASCADE;
