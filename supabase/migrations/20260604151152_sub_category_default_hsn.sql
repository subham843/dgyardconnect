-- Sub-category default HSN (products inherit when sub-category is selected)

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS default_hsn_code TEXT;

COMMENT ON COLUMN sub_categories.default_hsn_code IS 'Default HSN for products in this sub-category; copied on product create / sub-category change';
