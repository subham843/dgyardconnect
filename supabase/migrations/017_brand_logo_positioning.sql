-- Brand logo positioning + homepage showcase fields
-- Logos preserve original aspect ratio; admin controls scale/offset in canvas.

ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS logo_scale DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS logo_offset_x DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS logo_offset_y DOUBLE PRECISION NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS logo_background_color TEXT,
  ADD COLUMN IF NOT EXISTS logo_mime_type TEXT,
  ADD COLUMN IF NOT EXISTS short_description TEXT,
  ADD COLUMN IF NOT EXISTS is_featured_on_homepage BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN brands.logo_scale IS 'Zoom multiplier inside logo display canvas (1.0 = default contain fit)';
COMMENT ON COLUMN brands.logo_offset_x IS 'Horizontal pan offset (px) inside logo canvas';
COMMENT ON COLUMN brands.logo_offset_y IS 'Vertical pan offset (px) inside logo canvas';
COMMENT ON COLUMN brands.logo_background_color IS 'Optional hex background behind logo in canvas (#RRGGBB)';
COMMENT ON COLUMN brands.logo_mime_type IS 'MIME type of stored logo (image/png, image/svg+xml, image/webp, image/jpeg)';
COMMENT ON COLUMN brands.short_description IS 'Optional short tagline shown on homepage brand cards';
COMMENT ON COLUMN brands.is_featured_on_homepage IS 'Show brand in public homepage Trusted Brands section';
COMMENT ON COLUMN brands.display_order IS 'Sort order for featured brand displays (lower first)';

CREATE INDEX IF NOT EXISTS idx_brands_featured_homepage
  ON brands (is_featured_on_homepage, display_order)
  WHERE is_active = true AND is_featured_on_homepage = true;
