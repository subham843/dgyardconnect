-- Simplified SEO: admin edits title + description + slug; system stores canonical / OG

ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS image_url TEXT;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS og_image_override TEXT;

COMMENT ON COLUMN products.og_image IS 'Resolved OG image (override or main image)';
COMMENT ON COLUMN products.og_image_override IS 'Admin override only; null = use main product image';
COMMENT ON COLUMN categories.meta_keywords IS 'Deprecated — not used in admin';
COMMENT ON COLUMN products.seo_keywords IS 'Deprecated — not used in admin';

-- Backfill slugs and auto-generated SEO from existing data
UPDATE categories SET
  slug = COALESCE(NULLIF(TRIM(slug), ''), LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(name), '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g'))),
  og_title = COALESCE(NULLIF(TRIM(og_title), ''), seo_title),
  og_description = COALESCE(NULLIF(TRIM(og_description), ''), meta_description),
  og_image = COALESCE(NULLIF(TRIM(og_image), ''), image_url),
  canonical_url = COALESCE(
    NULLIF(TRIM(canonical_url), ''),
    'https://dgyard.com/shop/' || COALESCE(NULLIF(TRIM(slug), ''), 'category')
  )
WHERE slug IS NOT NULL OR name IS NOT NULL;

UPDATE sub_categories sc SET
  slug = COALESCE(NULLIF(TRIM(sc.slug), ''), LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(sc.name), '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g'))),
  og_title = COALESCE(NULLIF(TRIM(sc.og_title), ''), sc.seo_title),
  og_description = COALESCE(NULLIF(TRIM(sc.og_description), ''), sc.meta_description),
  og_image = COALESCE(NULLIF(TRIM(sc.og_image), ''), sc.image_url),
  canonical_url = COALESCE(
    NULLIF(TRIM(sc.canonical_url), ''),
    'https://dgyard.com/shop/' || COALESCE(c.slug, 'category') || '/' || COALESCE(NULLIF(TRIM(sc.slug), ''), 'subcategory')
  )
FROM categories c
WHERE c.id = sc.category_id;

UPDATE products SET
  url_slug = COALESCE(
    NULLIF(TRIM(url_slug), ''),
    LOWER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(name), '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g'))
  ),
  og_title = COALESCE(NULLIF(TRIM(og_title), ''), seo_title),
  og_description = COALESCE(NULLIF(TRIM(og_description), ''), seo_description),
  og_image_override = COALESCE(og_image_override, NULL),
  canonical_url = COALESCE(
    NULLIF(TRIM(canonical_url), ''),
    'https://dgyard.com/product/' || COALESCE(NULLIF(TRIM(url_slug), ''), sku)
  )
WHERE name IS NOT NULL;
