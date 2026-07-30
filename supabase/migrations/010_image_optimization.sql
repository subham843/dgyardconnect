-- Image Optimization: Multi-Image & Responsive Sizing Support

-- Product Images: Add optimized URLs
ALTER TABLE product_images
  ADD COLUMN IF NOT EXISTS webp_url TEXT,
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
  ADD COLUMN IF NOT EXISTS medium_url TEXT,
  ADD COLUMN IF NOT EXISTS large_url TEXT;

COMMENT ON COLUMN product_images.webp_url IS 
'WebP optimized version';

COMMENT ON COLUMN product_images.thumbnail_url IS 
'Thumbnail (400px) for cards';

COMMENT ON COLUMN product_images.medium_url IS 
'Medium (800px) for detail pages';

COMMENT ON COLUMN product_images.large_url IS 
'Large (1200px) for galleries';

-- Categories: Add multi-image support
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN categories.images IS 
'Multiple images array for category pages';

-- SubCategories: Add multi-image support
ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN sub_categories.images IS 
'Multiple images array for subcategory pages';

-- Backfill: Migrate single images to array
UPDATE categories SET
  images = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL 
  AND image_url <> ''
  AND (images IS NULL OR images = '[]'::jsonb);

UPDATE sub_categories SET
  images = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL 
  AND image_url <> ''
  AND (images IS NULL OR images = '[]'::jsonb);
