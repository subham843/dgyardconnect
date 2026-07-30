-- Shop Sections System for Dynamic Content Management
-- Admin can create sections like Featured, Best Sellers, New Arrivals, etc.

CREATE TABLE shop_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Section Type
  section_type VARCHAR(50) NOT NULL CHECK (section_type IN (
    'featured', 'bestsellers', 'new_arrivals', 'popular', 
    'recommended', 'trending', 'security_solutions', 
    'networking_solutions', 'software_solutions', 
    'smart_home_solutions', 'custom'
  )),
  
  -- Content
  title VARCHAR(200) NOT NULL,
  subtitle VARCHAR(300),
  description TEXT,
  
  -- Display Configuration
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  show_on_homepage BOOLEAN DEFAULT false,
  show_on_store BOOLEAN DEFAULT true,
  
  -- Layout Settings
  layout_type VARCHAR(50) DEFAULT 'grid' CHECK (layout_type IN ('grid', 'carousel', 'list')),
  items_per_row INT DEFAULT 4 CHECK (items_per_row BETWEEN 1 AND 6),
  max_items INT DEFAULT 8 CHECK (max_items BETWEEN 1 AND 50),
  
  -- Filtering Strategy
  filter_type VARCHAR(50) DEFAULT 'manual' CHECK (filter_type IN (
    'manual', 'auto_bestsellers', 'auto_new', 'auto_trending', 
    'auto_category', 'auto_featured'
  )),
  
  -- Auto-filter configuration (JSON)
  filter_config JSONB DEFAULT '{}'::jsonb,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT REFERENCES platform_users(firebase_uid),
  updated_by TEXT REFERENCES platform_users(firebase_uid)
);

-- Shop Section Products (Manual Selection)
CREATE TABLE shop_section_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id UUID NOT NULL REFERENCES shop_sections(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  display_order INT DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT REFERENCES platform_users(firebase_uid),
  
  UNIQUE(section_id, product_id)
);

-- Indexes
CREATE INDEX idx_shop_sections_active ON shop_sections(is_active, display_order);
CREATE INDEX idx_shop_sections_homepage ON shop_sections(show_on_homepage) WHERE show_on_homepage = true;
CREATE INDEX idx_shop_sections_store ON shop_sections(show_on_store) WHERE show_on_store = true;
CREATE INDEX idx_shop_sections_type ON shop_sections(section_type);

CREATE INDEX idx_section_products_section ON shop_section_products(section_id, display_order);
CREATE INDEX idx_section_products_product ON shop_section_products(product_id);

-- RLS Policies
ALTER TABLE shop_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_section_products ENABLE ROW LEVEL SECURITY;

-- Public can view active sections
CREATE POLICY "Public can view active sections"
  ON shop_sections FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

-- Public can view section products for active sections
CREATE POLICY "Public can view section products"
  ON shop_section_products FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM shop_sections
      WHERE id = section_id AND is_active = true
    )
  );

-- Only admins can manage sections
CREATE POLICY "Admins can manage sections"
  ON shop_sections FOR ALL
  TO authenticated
  USING (auth_is_superadmin());

CREATE POLICY "Admins can manage section products"
  ON shop_section_products FOR ALL
  TO authenticated
  USING (auth_is_superadmin());

-- Updated timestamp triggers
CREATE TRIGGER update_shop_sections_updated_at
  BEFORE UPDATE ON shop_sections
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Comments
COMMENT ON TABLE shop_sections IS 'Dynamic sections for homepage and store (Featured, Best Sellers, etc.)';
COMMENT ON TABLE shop_section_products IS 'Manual product selection for sections';
COMMENT ON COLUMN shop_sections.filter_type IS 'manual = admin selects products, auto_* = system populates automatically';
COMMENT ON COLUMN shop_sections.filter_config IS 'JSON config for auto-filters (e.g., {"category_id": "uuid", "days": 30})';
