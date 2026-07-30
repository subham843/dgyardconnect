-- Per-family subset of Shop attribute options shown to calculator users.
-- NULL = all current Shop options; non-null JSON array = only those labels.

ALTER TABLE calculator_family_attributes
  ADD COLUMN IF NOT EXISTS selected_options JSONB;

COMMENT ON COLUMN calculator_family_attributes.selected_options IS
  'Optional subset of attribute option labels for this family. Null = all Shop options.';
