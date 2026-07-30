-- Per-surface image framing (homepage card vs category banner vs mobile, etc.)

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS image_editor_source_url TEXT,
  ADD COLUMN IF NOT EXISTS image_editor_source_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS image_source_width INT,
  ADD COLUMN IF NOT EXISTS image_source_height INT,
  ADD COLUMN IF NOT EXISTS image_placements JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS image_editor_source_url TEXT,
  ADD COLUMN IF NOT EXISTS image_editor_source_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS image_source_width INT,
  ADD COLUMN IF NOT EXISTS image_source_height INT,
  ADD COLUMN IF NOT EXISTS image_placements JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS main_image_editor_source_url TEXT,
  ADD COLUMN IF NOT EXISTS main_image_editor_source_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS main_image_source_width INT,
  ADD COLUMN IF NOT EXISTS main_image_source_height INT,
  ADD COLUMN IF NOT EXISTS main_image_placements JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN categories.image_placements IS
'Per-surface framing JSON: homepage_card, category_banner, mobile_homepage, default';

DROP VIEW IF EXISTS v_public_categories;
CREATE VIEW v_public_categories AS
SELECT
  id,
  name,
  slug,
  sort_order,
  is_active,
  image_url,
  image_storage_path,
  og_image,
  image_editor_source_url,
  image_source_width,
  image_source_height,
  image_placements,
  seo_title,
  meta_description,
  canonical_url,
  og_title,
  og_description,
  meta_keywords,
  images,
  created_at,
  updated_at
FROM categories
WHERE is_active = true;

GRANT SELECT ON v_public_categories TO anon;
GRANT SELECT ON v_public_categories TO authenticated;

DROP VIEW IF EXISTS v_public_subcategories;
CREATE VIEW v_public_subcategories AS
SELECT
  id,
  category_id,
  name,
  slug,
  description,
  sort_order,
  is_active,
  image_url,
  image_storage_path,
  og_image,
  image_editor_source_url,
  image_source_width,
  image_source_height,
  image_placements,
  seo_title,
  meta_description,
  canonical_url,
  og_title,
  og_description,
  meta_keywords,
  images,
  created_at,
  updated_at
FROM sub_categories
WHERE is_active = true;

GRANT SELECT ON v_public_subcategories TO anon;
GRANT SELECT ON v_public_subcategories TO authenticated;
