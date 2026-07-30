-- Calculator Families: Add SEO Fields & Multi-Image Support

ALTER TABLE calculator_families
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS meta_description TEXT,
  ADD COLUMN IF NOT EXISTS canonical_url TEXT,
  ADD COLUMN IF NOT EXISTS og_title TEXT,
  ADD COLUMN IF NOT EXISTS og_description TEXT,
  ADD COLUMN IF NOT EXISTS og_image TEXT,
  ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb;

-- Comments
COMMENT ON COLUMN calculator_families.seo_title IS 
'Meta title for calculator family page';

COMMENT ON COLUMN calculator_families.meta_description IS 
'Meta description for SEO';

COMMENT ON COLUMN calculator_families.canonical_url IS 
'Canonical URL (auto-generated: https://dgyard.com/calculator/{slug})';

COMMENT ON COLUMN calculator_families.og_title IS 
'Open Graph title (defaults to seo_title)';

COMMENT ON COLUMN calculator_families.og_description IS 
'Open Graph description (defaults to meta_description)';

COMMENT ON COLUMN calculator_families.og_image IS 
'Open Graph image URL (1200x630)';

COMMENT ON COLUMN calculator_families.images IS 
'Multiple images for calculator family gallery';

-- Backfill default SEO values
UPDATE calculator_families SET
  seo_title = COALESCE(
    NULLIF(TRIM(seo_title), ''),
    name || ' Calculator - DG Yard'
  ),
  meta_description = COALESCE(
    NULLIF(TRIM(meta_description), ''),
    'Use our ' || name || ' calculator to estimate your requirements and get instant quotations.'
  ),
  canonical_url = COALESCE(
    NULLIF(TRIM(canonical_url), ''),
    'https://dgyard.com/calculator/' || slug
  ),
  og_title = COALESCE(
    NULLIF(TRIM(og_title), ''),
    name || ' Calculator'
  ),
  og_description = COALESCE(
    NULLIF(TRIM(og_description), ''),
    'Calculate ' || name || ' requirements with DG Yard professional calculator.'
  )
WHERE name IS NOT NULL;

-- Index for canonical URL lookups
CREATE INDEX IF NOT EXISTS idx_calculator_families_canonical 
ON calculator_families(canonical_url) 
WHERE canonical_url IS NOT NULL AND canonical_url <> '';
