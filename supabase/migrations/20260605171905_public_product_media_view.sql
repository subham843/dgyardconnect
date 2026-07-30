-- Public-safe product documents (datasheets / brochures) for the storefront.
-- product_media_assets RLS blocks anonymous reads; this view (running with the
-- definer's rights, like the other v_public_* views) exposes only the
-- document URLs for ACTIVE products. The shop-media storage bucket is already
-- public-read, so the public_url downloads work for anonymous visitors.

CREATE OR REPLACE VIEW v_public_product_media AS
SELECT
  m.id,
  m.product_id,
  m.media_type,
  m.public_url,
  m.file_name,
  m.mime_type,
  m.file_size_bytes,
  m.alt_text,
  m.sort_order
FROM product_media_assets m
WHERE m.media_type IN ('datasheet', 'brochure')
  AND EXISTS (
    SELECT 1 FROM products p
    WHERE p.id = m.product_id
      AND p.is_active = true
  );

COMMENT ON VIEW v_public_product_media IS
'Public-safe product documents (datasheets/brochures) for active products. Files served from public shop-media bucket.';

GRANT SELECT ON v_public_product_media TO anon, authenticated;
