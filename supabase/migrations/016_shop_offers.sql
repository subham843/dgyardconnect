-- Shop Offers System for Promotions & Discounts
-- Admin can create various offer types: flat discount, percentage, bundles, flash sales, etc.

CREATE TABLE shop_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Offer Type
  offer_type VARCHAR(50) NOT NULL CHECK (offer_type IN (
    'flat_discount', 'percentage', 'buy_more_save_more', 
    'bundle', 'festival', 'brand', 'category', 'flash'
  )),
  
  -- Content
  name VARCHAR(200) NOT NULL,
  description TEXT,
  banner_url TEXT,
  
  -- Discount Configuration
  discount_type VARCHAR(20) CHECK (discount_type IN ('flat', 'percentage')),
  discount_value DECIMAL(10,2),
  min_purchase_amount DECIMAL(10,2),
  max_discount_amount DECIMAL(10,2),
  
  -- Buy X Get Y Configuration (for bundles)
  buy_quantity INT,
  get_quantity INT,
  get_discount_percentage DECIMAL(5,2),
  
  -- Targeting
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  subcategory_id UUID REFERENCES sub_categories(id) ON DELETE SET NULL,
  
  -- Dates
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  
  -- Display
  priority INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  show_badge BOOLEAN DEFAULT true,
  badge_text VARCHAR(50),
  badge_color VARCHAR(7) DEFAULT '#FF7A00', -- Saffron default
  
  -- Terms & Conditions
  terms_conditions TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT REFERENCES platform_users(firebase_uid),
  updated_by TEXT REFERENCES platform_users(firebase_uid),
  
  -- Constraints
  CONSTRAINT valid_offer_dates CHECK (start_date < end_date),
  CONSTRAINT valid_discount CHECK (
    (discount_type = 'flat' AND discount_value > 0) OR
    (discount_type = 'percentage' AND discount_value > 0 AND discount_value <= 100) OR
    discount_type IS NULL
  )
);

-- Offer Products Mapping (Which products are included in offer)
CREATE TABLE shop_offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL REFERENCES shop_offers(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(offer_id, product_id)
);

-- Indexes
CREATE INDEX idx_shop_offers_active ON shop_offers(is_active, priority);
CREATE INDEX idx_shop_offers_dates ON shop_offers(start_date, end_date);
CREATE INDEX idx_shop_offers_type ON shop_offers(offer_type);
CREATE INDEX idx_shop_offers_category ON shop_offers(category_id) WHERE category_id IS NOT NULL;

CREATE INDEX idx_offer_products_offer ON shop_offer_products(offer_id);
CREATE INDEX idx_offer_products_product ON shop_offer_products(product_id);

-- RLS Policies
ALTER TABLE shop_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_offer_products ENABLE ROW LEVEL SECURITY;

-- Public can view active offers within date range
CREATE POLICY "Public can view active offers"
  ON shop_offers FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND start_date <= NOW()
    AND end_date >= NOW()
  );

-- Public can view offer products for active offers
CREATE POLICY "Public can view offer products"
  ON shop_offer_products FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM shop_offers
      WHERE id = offer_id 
      AND is_active = true
      AND start_date <= NOW()
      AND end_date >= NOW()
    )
  );

-- Only admins can manage offers
CREATE POLICY "Admins can manage offers"
  ON shop_offers FOR ALL
  TO authenticated
  USING (auth_is_superadmin());

CREATE POLICY "Admins can manage offer products"
  ON shop_offer_products FOR ALL
  TO authenticated
  USING (auth_is_superadmin());

-- Updated timestamp trigger
CREATE TRIGGER update_shop_offers_updated_at
  BEFORE UPDATE ON shop_offers
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Helpful view: Active offers with product count
CREATE OR REPLACE VIEW v_active_offers AS
SELECT 
  o.*,
  COUNT(DISTINCT op.product_id) as product_count
FROM shop_offers o
LEFT JOIN shop_offer_products op ON o.id = op.offer_id
WHERE o.is_active = true
  AND o.start_date <= NOW()
  AND o.end_date >= NOW()
GROUP BY o.id;

-- Grant access to view
GRANT SELECT ON v_active_offers TO anon, authenticated;

-- Comments
COMMENT ON TABLE shop_offers IS 'Promotional offers and discounts managed by admin';
COMMENT ON TABLE shop_offer_products IS 'Products included in specific offers';
COMMENT ON COLUMN shop_offers.priority IS 'Higher priority offers display first';
COMMENT ON COLUMN shop_offers.badge_color IS 'Hex color for offer badge (default: Saffron #FF7A00)';
