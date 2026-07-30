-- Scope calculator rules to a family attribute option (e.g. Camera Type = HD).
-- Stable labels (not path row ids) so family path recreate does not orphan rules.

ALTER TABLE calculator_rules
  ADD COLUMN IF NOT EXISTS option_scope_family_id UUID REFERENCES calculator_families (id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS option_scope_attribute_id UUID REFERENCES attribute_master (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS option_scope_label TEXT;

CREATE INDEX IF NOT EXISTS idx_calculator_rules_option_scope
  ON calculator_rules (option_scope_family_id, option_scope_attribute_id, option_scope_label);

COMMENT ON COLUMN calculator_rules.option_scope_label IS
  'When set with family + attribute id, this rule belongs to that option path (e.g. HD).';
