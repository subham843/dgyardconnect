-- Platform media attribution + brand logos (image search workflow)

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS image_source_url TEXT,
  ADD COLUMN IF NOT EXISTS image_source_provider TEXT,
  ADD COLUMN IF NOT EXISTS image_attribution TEXT;

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS image_source_url TEXT,
  ADD COLUMN IF NOT EXISTS image_source_provider TEXT,
  ADD COLUMN IF NOT EXISTS image_attribution TEXT;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS main_image_source_url TEXT,
  ADD COLUMN IF NOT EXISTS main_image_source_provider TEXT,
  ADD COLUMN IF NOT EXISTS main_image_attribution TEXT;

ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS logo_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS logo_thumb_path TEXT,
  ADD COLUMN IF NOT EXISTS logo_alt_text TEXT,
  ADD COLUMN IF NOT EXISTS image_source_url TEXT,
  ADD COLUMN IF NOT EXISTS image_source_provider TEXT,
  ADD COLUMN IF NOT EXISTS image_attribution TEXT;

ALTER TABLE product_media_assets
  ADD COLUMN IF NOT EXISTS source_url TEXT,
  ADD COLUMN IF NOT EXISTS source_provider TEXT,
  ADD COLUMN IF NOT EXISTS attribution TEXT;

COMMENT ON COLUMN categories.image_source_url IS 'Original URL when image selected via search (not storage URL)';
COMMENT ON COLUMN categories.image_attribution IS 'Photographer / license line from search provider';
