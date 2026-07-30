-- Per option quotation paths: when customer picks e.g. Camera Type = HD,
-- show a different set of follow-up attributes than Wifi / IP / PTZ.

CREATE TABLE IF NOT EXISTS calculator_family_option_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  parent_attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  option_label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  UNIQUE (family_id, parent_attribute_id, option_label)
);

CREATE INDEX IF NOT EXISTS idx_cfop_family ON calculator_family_option_paths (family_id);
CREATE INDEX IF NOT EXISTS idx_cfop_parent ON calculator_family_option_paths (family_id, parent_attribute_id);

CREATE TABLE IF NOT EXISTS calculator_family_option_path_attributes (
  path_id UUID NOT NULL REFERENCES calculator_family_option_paths (id) ON DELETE CASCADE,
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  selected_options JSONB,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (path_id, attribute_id)
);

CREATE INDEX IF NOT EXISTS idx_cfopa_path ON calculator_family_option_path_attributes (path_id);

ALTER TABLE calculator_family_option_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_family_option_path_attributes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_family_option_paths_read ON calculator_family_option_paths;
CREATE POLICY calculator_family_option_paths_read ON calculator_family_option_paths FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_family_option_paths.family_id AND f.is_active = true
    )
  );

DROP POLICY IF EXISTS calculator_family_option_paths_write ON calculator_family_option_paths;
CREATE POLICY calculator_family_option_paths_write ON calculator_family_option_paths FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS calculator_family_option_path_attributes_read ON calculator_family_option_path_attributes;
CREATE POLICY calculator_family_option_path_attributes_read ON calculator_family_option_path_attributes FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1
      FROM calculator_family_option_paths p
      JOIN calculator_families f ON f.id = p.family_id
      WHERE p.id = calculator_family_option_path_attributes.path_id
        AND f.is_active = true
    )
  );

DROP POLICY IF EXISTS calculator_family_option_path_attributes_write ON calculator_family_option_path_attributes;
CREATE POLICY calculator_family_option_path_attributes_write ON calculator_family_option_path_attributes FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS "public_read_calculator_family_option_paths" ON calculator_family_option_paths;
CREATE POLICY "public_read_calculator_family_option_paths" ON calculator_family_option_paths
  FOR SELECT TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_family_option_paths.family_id AND f.is_active = true
    )
  );

DROP POLICY IF EXISTS "public_read_calculator_family_option_path_attributes" ON calculator_family_option_path_attributes;
CREATE POLICY "public_read_calculator_family_option_path_attributes" ON calculator_family_option_path_attributes
  FOR SELECT TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM calculator_family_option_paths p
      JOIN calculator_families f ON f.id = p.family_id
      WHERE p.id = calculator_family_option_path_attributes.path_id
        AND f.is_active = true
    )
  );

COMMENT ON TABLE calculator_family_option_paths IS
  'Quotation path per parent attribute option (e.g. Camera Type = HD).';
COMMENT ON TABLE calculator_family_option_path_attributes IS
  'Follow-up shop attributes shown when that option is selected.';
