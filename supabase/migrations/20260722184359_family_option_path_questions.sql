-- Custom questions belonging to a per-option quotation path
-- (e.g. when Camera Type = HD, show these questions).

CREATE TABLE IF NOT EXISTS calculator_family_option_path_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  path_id UUID NOT NULL REFERENCES calculator_family_option_paths (id) ON DELETE CASCADE,
  question_key TEXT NOT NULL,
  label TEXT NOT NULL,
  ui_type TEXT NOT NULL DEFAULT 'select',
  options JSONB,
  source_attribute_id UUID REFERENCES attribute_master (id) ON DELETE SET NULL,
  sort_order INT NOT NULL DEFAULT 0,
  UNIQUE (path_id, question_key)
);

CREATE INDEX IF NOT EXISTS idx_cfopq_path ON calculator_family_option_path_questions (path_id);

ALTER TABLE calculator_family_option_path_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_family_option_path_questions_read ON calculator_family_option_path_questions;
CREATE POLICY calculator_family_option_path_questions_read ON calculator_family_option_path_questions FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1
      FROM calculator_family_option_paths p
      JOIN calculator_families f ON f.id = p.family_id
      WHERE p.id = calculator_family_option_path_questions.path_id
        AND f.is_active = true
    )
  );

DROP POLICY IF EXISTS calculator_family_option_path_questions_write ON calculator_family_option_path_questions;
CREATE POLICY calculator_family_option_path_questions_write ON calculator_family_option_path_questions FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS "public_read_calculator_family_option_path_questions" ON calculator_family_option_path_questions;
CREATE POLICY "public_read_calculator_family_option_path_questions" ON calculator_family_option_path_questions
  FOR SELECT TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM calculator_family_option_paths p
      JOIN calculator_families f ON f.id = p.family_id
      WHERE p.id = calculator_family_option_path_questions.path_id
        AND f.is_active = true
    )
  );

COMMENT ON TABLE calculator_family_option_path_questions IS
  'Questions shown only when the parent option path is selected (e.g. Camera Type = HD).';
