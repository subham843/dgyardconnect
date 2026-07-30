-- Public CMS Content Management System
-- Admin manages homepage content, testimonials, partners, featured items
-- Featured items LINK to live category/subcategory/product records (not copies)

CREATE TABLE IF NOT EXISTS public_cms_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  content_type TEXT NOT NULL CHECK (content_type IN (
    'homepage_seo',
    'hero_banner',
    'hero_video',
    'featured_category',
    'featured_subcategory',
    'featured_product',
    'testimonial',
    'partner_logo',
    'cta_section',
    'why_section',
    'solution_card'
  )),
  
  title TEXT,
  subtitle TEXT,
  description TEXT,
  image_url TEXT,
  images JSONB DEFAULT '[]'::jsonb,
  video_url TEXT,
  cta_text TEXT,
  cta_link TEXT,
  
  -- LIVE FOREIGN KEY LINKS (SEO pulled from linked records at render time)
  featured_category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  featured_subcategory_id UUID REFERENCES sub_categories(id) ON DELETE SET NULL,
  featured_product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  
  metadata JSONB DEFAULT '{}'::jsonb,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  
  -- SEO fields (for homepage and custom pages)
  seo_title TEXT,
  meta_description TEXT,
  canonical_url TEXT,
  og_title TEXT,
  og_description TEXT,
  og_image TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT REFERENCES platform_users(firebase_uid) ON DELETE SET NULL,
  updated_by TEXT REFERENCES platform_users(firebase_uid) ON DELETE SET NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cms_content_type_active 
ON public_cms_content(content_type, is_active, sort_order);

CREATE INDEX IF NOT EXISTS idx_cms_featured_category 
ON public_cms_content(featured_category_id) 
WHERE featured_category_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cms_featured_subcategory 
ON public_cms_content(featured_subcategory_id) 
WHERE featured_subcategory_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cms_featured_product 
ON public_cms_content(featured_product_id) 
WHERE featured_product_id IS NOT NULL;

-- Comments
COMMENT ON TABLE public_cms_content IS 
'CMS content for public website. Featured items use FK links to live category/subcategory/product records for automatic SEO updates.';

COMMENT ON COLUMN public_cms_content.featured_category_id IS 
'LIVE LINK to category record. SEO values pulled from categories table at render time.';

COMMENT ON COLUMN public_cms_content.featured_subcategory_id IS 
'LIVE LINK to subcategory record. SEO values pulled from sub_categories table at render time.';

COMMENT ON COLUMN public_cms_content.featured_product_id IS 
'LIVE LINK to product record. SEO values pulled from products table at render time.';

-- RLS Policies
ALTER TABLE public_cms_content ENABLE ROW LEVEL SECURITY;

-- Superadmin full access
DROP POLICY IF EXISTS "superadmin_manage_cms" ON public_cms_content;
CREATE POLICY "superadmin_manage_cms" ON public_cms_content
FOR ALL TO authenticated
USING (auth_is_superadmin())
WITH CHECK (auth_is_superadmin());

-- Anonymous read active content
DROP POLICY IF EXISTS "public_read_active_cms" ON public_cms_content;
CREATE POLICY "public_read_active_cms" ON public_cms_content
FOR SELECT TO anon
USING (is_active = true);

-- Authenticated read active content
DROP POLICY IF EXISTS "authenticated_read_active_cms" ON public_cms_content;
CREATE POLICY "authenticated_read_active_cms" ON public_cms_content
FOR SELECT TO authenticated
USING (is_active = true OR auth_is_superadmin());

-- Trigger
CREATE TRIGGER set_updated_at_cms 
BEFORE UPDATE ON public_cms_content
FOR EACH ROW 
EXECUTE FUNCTION set_updated_at();

-- Seed default homepage SEO
INSERT INTO public_cms_content (
  content_type,
  seo_title,
  meta_description,
  canonical_url,
  og_title,
  og_description,
  og_image,
  is_active,
  metadata
) VALUES (
  'homepage_seo',
  'DG Yard - Professional Security & IT Solutions',
  'Digital. Smart. Secure. DG Yard provides security systems, IT infrastructure, and professional services for residential, commercial, and industrial projects.',
  'https://dgyard.com/',
  'DG Yard - Digital. Smart. Secure.',
  'Professional security and IT solutions platform for modern infrastructure',
  'https://dgyard.com/og-homepage.jpg',
  true,
  '{"keywords": ["security systems", "IT infrastructure", "CCTV", "networking", "smart home"], "schema_type": "Organization"}'::jsonb
)
ON CONFLICT DO NOTHING;
