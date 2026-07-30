-- Shop Banners System for CMS Management
-- Admin can manage homepage, store, category, subcategory, offer, festival, and brand banners

CREATE TABLE shop_banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Banner Type
  banner_type VARCHAR(50) NOT NULL CHECK (banner_type IN (
    'homepage', 'store', 'category', 'subcategory', 
    'offer', 'festival', 'brand'
  )),
  
  -- Content
  title VARCHAR(200) NOT NULL,
  subtitle VARCHAR(300),
  description TEXT,
  
  -- Images
  image_url TEXT NOT NULL,
  mobile_image_url TEXT,
  alt_text VARCHAR(200),
  
  -- Call to Action
  cta_text VARCHAR(100),
  cta_url VARCHAR(500),
  
  -- Display Configuration
  display_order INT DEFAULT 0,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  
  -- Targeting (Optional - for category/subcategory specific banners)
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  subcategory_id UUID REFERENCES sub_categories(id) ON DELETE CASCADE,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT REFERENCES platform_users(firebase_uid),
  updated_by TEXT REFERENCES platform_users(firebase_uid),
  
  -- Constraints
  CONSTRAINT valid_dates CHECK (start_date IS NULL OR end_date IS NULL OR start_date < end_date)
);

-- Indexes for performance
CREATE INDEX idx_shop_banners_active ON shop_banners(is_active, display_order);
CREATE INDEX idx_shop_banners_type ON shop_banners(banner_type);
CREATE INDEX idx_shop_banners_dates ON shop_banners(start_date, end_date);
CREATE INDEX idx_shop_banners_category ON shop_banners(category_id) WHERE category_id IS NOT NULL;
CREATE INDEX idx_shop_banners_subcategory ON shop_banners(subcategory_id) WHERE subcategory_id IS NOT NULL;

-- RLS Policies
ALTER TABLE shop_banners ENABLE ROW LEVEL SECURITY;

-- Public can view active banners within date range
CREATE POLICY "Public can view active banners"
  ON shop_banners FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND (start_date IS NULL OR start_date <= NOW())
    AND (end_date IS NULL OR end_date >= NOW())
  );

-- Authenticated users can view all banners
CREATE POLICY "Authenticated can view all banners"
  ON shop_banners FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can manage banners
CREATE POLICY "Admins can manage banners"
  ON shop_banners FOR ALL
  TO authenticated
  USING (auth_is_superadmin());

-- Updated timestamp trigger
CREATE TRIGGER update_shop_banners_updated_at
  BEFORE UPDATE ON shop_banners
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Comments
COMMENT ON TABLE shop_banners IS 'CMS-managed banners for homepage, store, and promotional displays';
COMMENT ON COLUMN shop_banners.banner_type IS 'Type of banner: homepage, store, category, subcategory, offer, festival, brand';
COMMENT ON COLUMN shop_banners.display_order IS 'Lower numbers display first (0 = highest priority)';
