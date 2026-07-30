-- Named folders for calculator rules (e.g. Recorders, Power, Cabling) so many
-- rules can sit under one group without inventing a unique name each time.

CREATE TABLE IF NOT EXISTS calculator_rule_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  option_scope_attribute_id UUID REFERENCES attribute_master (id) ON DELETE SET NULL,
  option_scope_label TEXT,
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crg_family_scope
  ON calculator_rule_groups (family_id, option_scope_attribute_id, option_scope_label, sort_order);

ALTER TABLE calculator_rules
  ADD COLUMN IF NOT EXISTS rule_group_id UUID REFERENCES calculator_rule_groups (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_calculator_rules_group
  ON calculator_rules (rule_group_id);

ALTER TABLE calculator_rule_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_rule_groups_read ON calculator_rule_groups;
CREATE POLICY calculator_rule_groups_read ON calculator_rule_groups FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_rule_groups.family_id
        AND (f.is_active = true OR auth_firebase_uid() <> '')
    )
  );

DROP POLICY IF EXISTS calculator_rule_groups_write ON calculator_rule_groups;
CREATE POLICY calculator_rule_groups_write ON calculator_rule_groups FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS "public_read_calculator_rule_groups" ON calculator_rule_groups;
CREATE POLICY "public_read_calculator_rule_groups" ON calculator_rule_groups
  FOR SELECT TO anon, authenticated
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_rule_groups.family_id AND f.is_active = true
    )
  );

COMMENT ON TABLE calculator_rule_groups IS
  'Admin folders for option-scoped (or family) calculator rules.';
COMMENT ON COLUMN calculator_rules.rule_group_id IS
  'Optional folder — multiple rules share a display group name.';