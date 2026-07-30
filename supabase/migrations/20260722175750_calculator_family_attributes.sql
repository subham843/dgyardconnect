-- Link calculator families to Shop Attribute Master (e.g. CCTV → Camera Type, Storage Capacity).
-- Public calculator shows these attributes as selectable questions with live options.

CREATE TABLE IF NOT EXISTS calculator_family_attributes (
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (family_id, attribute_id)
);

CREATE INDEX IF NOT EXISTS idx_cfa_family ON calculator_family_attributes (family_id);
CREATE INDEX IF NOT EXISTS idx_cfa_attribute ON calculator_family_attributes (attribute_id);

ALTER TABLE calculator_family_attributes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calculator_family_attributes_read ON calculator_family_attributes;
CREATE POLICY calculator_family_attributes_read ON calculator_family_attributes FOR SELECT
  USING (
    auth_is_superadmin()
    OR EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_family_attributes.family_id
        AND f.is_active = true
    )
  );

DROP POLICY IF EXISTS calculator_family_attributes_write ON calculator_family_attributes;
CREATE POLICY calculator_family_attributes_write ON calculator_family_attributes FOR ALL
  USING (auth_is_superadmin())
  WITH CHECK (auth_is_superadmin());

DROP POLICY IF EXISTS "public_read_calculator_family_attributes" ON calculator_family_attributes;
CREATE POLICY "public_read_calculator_family_attributes" ON calculator_family_attributes
  FOR SELECT TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM calculator_families f
      WHERE f.id = calculator_family_attributes.family_id
        AND f.is_active = true
    )
  );

COMMENT ON TABLE calculator_family_attributes IS
  'Shop attributes assigned to a calculator family; drives public form fields + options.';
