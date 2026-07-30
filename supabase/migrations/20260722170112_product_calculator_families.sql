-- Many-to-many: one product (e.g. Hard Disk) can belong to multiple calculator families.
CREATE TABLE IF NOT EXISTS product_calculator_families (
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  priority INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, family_id)
);

CREATE INDEX IF NOT EXISTS idx_pcf_family ON product_calculator_families (family_id);
CREATE INDEX IF NOT EXISTS idx_pcf_product ON product_calculator_families (product_id);

INSERT INTO product_calculator_families (product_id, family_id, priority)
SELECT id, calculator_family_id, COALESCE(calculator_priority, 0)
FROM products
WHERE calculator_family_id IS NOT NULL
ON CONFLICT (product_id, family_id) DO NOTHING;

ALTER TABLE product_calculator_families ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_calculator_families_read ON product_calculator_families;
CREATE POLICY product_calculator_families_read ON product_calculator_families FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM products p
      WHERE p.id = product_id AND (p.is_active = true OR auth_is_superadmin())
    )
    OR auth_firebase_uid() <> ''
  );

DROP POLICY IF EXISTS product_calculator_families_write ON product_calculator_families;
CREATE POLICY product_calculator_families_write ON product_calculator_families FOR ALL
  USING (auth_is_superadmin())
  WITH CHECK (auth_is_superadmin());