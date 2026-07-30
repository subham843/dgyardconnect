-- Expose product main-image editor framing on the public storefront view.

DROP VIEW IF EXISTS v_public_products;
CREATE VIEW v_public_products AS
SELECT
  id,
  sub_category_id,
  brand_id,
  sku,
  name,
  description,
  short_description,
  technical_notes,
  installation_notes,
  online_price,
  mrp,
  selling_price,
  model_name,
  warranty,
  warranty_months,
  tax_percentage,
  use_gst_override,
  is_active,
  track_serial,
  track_batch,
  url_slug,
  seo_title,
  seo_description,
  seo_keywords,
  canonical_url,
  og_title,
  og_description,
  og_image,
  og_image_override,
  main_image_editor_source_url,
  main_image_source_width,
  main_image_source_height,
  main_image_placements,
  show_in_calculator,
  calculator_family_id,
  calculator_priority,
  metadata,
  created_at,
  updated_at
FROM products
WHERE is_active = true;

GRANT SELECT ON v_public_products TO anon;
GRANT SELECT ON v_public_products TO authenticated;

COMMENT ON VIEW v_public_products IS
'Public-safe product view with per-surface main image placements for storefront rendering.';
