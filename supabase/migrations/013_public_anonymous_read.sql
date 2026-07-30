-- Public Anonymous Read Access via Secure Views
-- Anonymous users can ONLY access views, not tables directly
-- Sensitive columns (cost_price, dealer_price) excluded from views

-- ============================================================================
-- PUBLIC-SAFE VIEWS (Exclude Sensitive Columns)
-- ============================================================================

-- Categories (Safe - no sensitive data)
CREATE OR REPLACE VIEW v_public_categories AS
SELECT
  id,
  name,
  slug,
  sort_order,
  is_active,
  image_url,
  image_storage_path,
  og_image,
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

COMMENT ON VIEW v_public_categories IS 
'Public-safe category view for anonymous users. No sensitive data.';

-- SubCategories (Safe - no sensitive data)
CREATE OR REPLACE VIEW v_public_subcategories AS
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
  seo_title,
  meta_description,
  canonical_url,
  og_title,
  og_description,
  images,
  default_hsn_code,
  default_gst_percentage,
  created_at,
  updated_at
FROM sub_categories
WHERE is_active = true;

COMMENT ON VIEW v_public_subcategories IS 
'Public-safe subcategory view for anonymous users. No sensitive data.';

-- Products (SECURED - excludes cost_price, dealer_price, distributor_price)
CREATE OR REPLACE VIEW v_public_products AS
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
  
  -- PUBLIC PRICING ONLY
  online_price,
  mrp,
  selling_price,
  -- EXCLUDED: cost_price, dealer_price, distributor_price
  
  model_name,
  warranty,
  warranty_months,
  tax_percentage,
  use_gst_override,
  
  is_active,
  track_serial,
  track_batch,
  
  -- SEO fields
  url_slug,
  seo_title,
  seo_description,
  seo_keywords,
  canonical_url,
  og_title,
  og_description,
  og_image,
  og_image_override,
  
  -- Calculator integration
  show_in_calculator,
  calculator_family_id,
  calculator_priority,
  
  metadata,
  created_at,
  updated_at
FROM products
WHERE is_active = true;

COMMENT ON VIEW v_public_products IS 
'Public-safe product view. Excludes: cost_price, dealer_price, distributor_price. Only active products visible.';

-- Product Attributes (Safe - linked to active products)
CREATE OR REPLACE VIEW v_public_product_attributes AS
SELECT
  pa.id,
  pa.product_id,
  pa.attribute_id,
  pa.value_text,
  pa.value_number,
  pa.value_json,
  am.key AS attribute_key,
  am.label AS attribute_label,
  am.data_type,
  am.unit
FROM product_attributes pa
JOIN attribute_master am ON am.id = pa.attribute_id
WHERE EXISTS (
  SELECT 1 FROM products p
  WHERE p.id = pa.product_id
  AND p.is_active = true
);

COMMENT ON VIEW v_public_product_attributes IS 
'Public-safe product attributes. Filtered to active products only.';

-- Product Images (Safe - linked to active products)
CREATE OR REPLACE VIEW v_public_product_images AS
SELECT
  pi.id,
  pi.product_id,
  pi.url,
  pi.sort_order,
  pi.webp_url,
  pi.thumbnail_url,
  pi.medium_url,
  pi.large_url
FROM product_images pi
WHERE EXISTS (
  SELECT 1 FROM products p
  WHERE p.id = pi.product_id
  AND p.is_active = true
);

COMMENT ON VIEW v_public_product_images IS 
'Public-safe product images. Filtered to active products only.';

-- Calculator Families (Safe - no sensitive data)
CREATE OR REPLACE VIEW v_public_calculator_families AS
SELECT
  id,
  name,
  slug,
  description,
  sort_order,
  is_active,
  seo_title,
  meta_description,
  canonical_url,
  og_title,
  og_description,
  og_image,
  images,
  created_at,
  updated_at
FROM calculator_families
WHERE is_active = true;

COMMENT ON VIEW v_public_calculator_families IS 
'Public-safe calculator families view for anonymous users.';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant SELECT on views to anonymous users
GRANT SELECT ON v_public_categories TO anon;
GRANT SELECT ON v_public_subcategories TO anon;
GRANT SELECT ON v_public_products TO anon;
GRANT SELECT ON v_public_product_attributes TO anon;
GRANT SELECT ON v_public_product_images TO anon;
GRANT SELECT ON v_public_calculator_families TO anon;

-- Authenticated users can also use views (but they have table access too)
GRANT SELECT ON v_public_categories TO authenticated;
GRANT SELECT ON v_public_subcategories TO authenticated;
GRANT SELECT ON v_public_products TO authenticated;
GRANT SELECT ON v_public_product_attributes TO authenticated;
GRANT SELECT ON v_public_product_images TO authenticated;
GRANT SELECT ON v_public_calculator_families TO authenticated;

-- ============================================================================
-- RLS POLICIES FOR NON-VIEW TABLES (Anonymous Access)
-- ============================================================================

-- Brands (Safe - no view needed)
DROP POLICY IF EXISTS "public_read_brands" ON brands;
CREATE POLICY "public_read_brands" ON brands
FOR SELECT TO anon
USING (is_active = true);

-- Attribute Master (Safe - for filters)
DROP POLICY IF EXISTS "public_read_attribute_master" ON attribute_master;
CREATE POLICY "public_read_attribute_master" ON attribute_master
FOR SELECT TO anon
USING (is_active = true);

-- Attribute Options (Safe)
DROP POLICY IF EXISTS "public_read_attribute_options" ON attribute_options;
CREATE POLICY "public_read_attribute_options" ON attribute_options
FOR SELECT TO anon
USING (
  EXISTS (
    SELECT 1 FROM attribute_master
    WHERE id = attribute_id
    AND is_active = true
  )
);

-- Attribute Groups (Safe)
DROP POLICY IF EXISTS "public_read_attribute_groups" ON attribute_groups;
CREATE POLICY "public_read_attribute_groups" ON attribute_groups
FOR SELECT TO anon
USING (true);

-- Calculator Templates
DROP POLICY IF EXISTS "public_read_calculator_templates" ON calculator_templates;
CREATE POLICY "public_read_calculator_templates" ON calculator_templates
FOR SELECT TO anon
USING (is_published = true AND is_active = true);

-- Calculator Questions
DROP POLICY IF EXISTS "public_read_calculator_questions" ON calculator_questions;
CREATE POLICY "public_read_calculator_questions" ON calculator_questions
FOR SELECT TO anon
USING (
  EXISTS (
    SELECT 1 FROM calculator_templates
    WHERE id = template_id
    AND is_published = true
    AND is_active = true
  )
);

-- Calculator Rules
DROP POLICY IF EXISTS "public_read_calculator_rules" ON calculator_rules;
CREATE POLICY "public_read_calculator_rules" ON calculator_rules
FOR SELECT TO anon
USING (
  EXISTS (
    SELECT 1 FROM calculator_templates
    WHERE id = template_id
    AND is_published = true
    AND is_active = true
  )
);

-- ============================================================================
-- SECURITY SUMMARY
-- ============================================================================
-- 1. Anonymous users access products via v_public_products VIEW (not table)
-- 2. Sensitive columns (cost_price, dealer_price, distributor_price) excluded from view
-- 3. Authenticated users continue using tables directly (unchanged)
-- 4. Superadmin bypasses all restrictions (unchanged)
