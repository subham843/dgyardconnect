-- Shop media: Supabase Storage bucket + asset metadata (no manual URL entry)

DO $$ BEGIN
  CREATE TYPE shop_media_type AS ENUM ('main', 'gallery', 'datasheet', 'brochure');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Category / subcategory media paths (public URL denormalized for storefront + OG)
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS image_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS image_thumb_path TEXT,
  ADD COLUMN IF NOT EXISTS image_webp_path TEXT,
  ADD COLUMN IF NOT EXISTS image_alt_text TEXT;

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS image_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS image_thumb_path TEXT,
  ADD COLUMN IF NOT EXISTS image_webp_path TEXT,
  ADD COLUMN IF NOT EXISTS image_alt_text TEXT;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS main_image_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS main_image_thumb_path TEXT,
  ADD COLUMN IF NOT EXISTS main_image_alt_text TEXT;

-- Unified product files (gallery, datasheets, brochures + optional main mirror)
CREATE TABLE IF NOT EXISTS product_media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  media_type shop_media_type NOT NULL,
  storage_path TEXT NOT NULL,
  public_url TEXT NOT NULL,
  webp_path TEXT,
  thumb_path TEXT,
  alt_text TEXT,
  file_name TEXT,
  mime_type TEXT,
  file_size_bytes BIGINT,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_media_assets_product ON product_media_assets (product_id, media_type, sort_order);

-- Storage bucket (public read for storefront)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shop-media',
  'shop-media',
  true,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- RLS: public read, authenticated superadmin write
DROP POLICY IF EXISTS shop_media_public_read ON storage.objects;
CREATE POLICY shop_media_public_read ON storage.objects FOR SELECT
  USING (bucket_id = 'shop-media');

DROP POLICY IF EXISTS shop_media_admin_write ON storage.objects;
CREATE POLICY shop_media_admin_write ON storage.objects FOR ALL
  USING (bucket_id = 'shop-media' AND auth_is_superadmin())
  WITH CHECK (bucket_id = 'shop-media' AND auth_is_superadmin());

ALTER TABLE product_media_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS product_media_read ON product_media_assets;
CREATE POLICY product_media_read ON product_media_assets FOR SELECT
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
DROP POLICY IF EXISTS product_media_write ON product_media_assets;
CREATE POLICY product_media_write ON product_media_assets FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

COMMENT ON TABLE product_media_assets IS 'Uploaded shop product media; URLs derived from Supabase Storage';
COMMENT ON COLUMN categories.image_url IS 'Legacy public URL; auto-set from storage on upload';
