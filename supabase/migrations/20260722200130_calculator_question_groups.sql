-- Question groups per calculator family (Camera, Storage, Accessories, …).

CREATE TABLE IF NOT EXISTS calculator_question_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cqg_family
  ON calculator_question_groups (family_id, sort_order);

ALTER TABLE calculator_family_attributes
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES calculator_question_groups (id) ON DELETE SET NULL;

ALTER TABLE calculator_family_option_path_questions
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES calculator_question_groups (id) ON DELETE SET NULL;

ALTER TABLE calculator_questions
  ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES calculator_question_groups (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_cfa_group ON calculator_family_attributes (group_id);
CREATE INDEX IF NOT EXISTS idx_cfopq_group ON calculator_family_option_path_questions (group_id);
CREATE INDEX IF NOT EXISTS idx_cq_group ON calculator_questions (group_id);

ALTER TABLE calculator_question_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_question_groups_read ON calculator_question_groups;
CREATE POLICY calculator_question_groups_read ON calculator_question_groups FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_question_groups.family_id
        AND (f.is_active = true OR auth_firebase_uid() <> '')
    )
  );

DROP POLICY IF EXISTS calculator_question_groups_write ON calculator_question_groups;
CREATE POLICY calculator_question_groups_write ON calculator_question_groups FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS "public_read_calculator_question_groups" ON calculator_question_groups;
CREATE POLICY "public_read_calculator_question_groups" ON calculator_question_groups
  FOR SELECT TO anon, authenticated
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_question_groups.family_id AND f.is_active = true
    )
  );

COMMENT ON TABLE calculator_question_groups IS
  'Named sections for calculator questions (e.g. Camera, Storage, Accessories).';
