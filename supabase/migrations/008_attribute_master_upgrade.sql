-- Attribute Master upgrade: new data types, flags, structured options (backward compatible)

ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'long_text';
ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'multi_select';
ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'date';

ALTER TABLE attribute_master
  ADD COLUMN IF NOT EXISTS is_required BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS use_in_filter BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS use_in_calculator BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN attribute_master.is_active IS 'Status: active when true';
COMMENT ON COLUMN attribute_master.allowed_values IS 'Legacy JSON options; kept in sync with attribute_options for compatibility';

CREATE TABLE IF NOT EXISTS attribute_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attribute_options_attribute ON attribute_options (attribute_id, sort_order);

CREATE TRIGGER trg_attribute_options_updated
  BEFORE UPDATE ON attribute_options
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Migrate existing allowed_values JSONB into attribute_options (no deletes)
INSERT INTO attribute_options (attribute_id, label, sort_order, is_active)
SELECT
  am.id,
  opt.value::text,
  (opt.ordinality - 1)::int,
  true
FROM attribute_master am
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(am.allowed_values, '[]'::jsonb)) WITH ORDINALITY AS opt(value, ordinality)
WHERE am.data_type::text IN ('select', 'multi_select')
  AND jsonb_array_length(COALESCE(am.allowed_values, '[]'::jsonb)) > 0
  AND NOT EXISTS (
    SELECT 1 FROM attribute_options ao WHERE ao.attribute_id = am.id
  );

ALTER TABLE attribute_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY attribute_options_read ON attribute_options
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());

CREATE POLICY attribute_options_write ON attribute_options
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());
