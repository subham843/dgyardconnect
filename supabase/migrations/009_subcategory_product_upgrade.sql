-- SubCategory + Product admin upgrade (backward compatible)

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS description TEXT;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS barcode TEXT,
  ADD COLUMN IF NOT EXISTS product_type TEXT,
  ADD COLUMN IF NOT EXISTS hsn_code TEXT,
  ADD COLUMN IF NOT EXISTS tax_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS warranty TEXT,
  ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS selling_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS dealer_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS distributor_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS mrp NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS short_description TEXT,
  ADD COLUMN IF NOT EXISTS technical_notes TEXT,
  ADD COLUMN IF NOT EXISTS installation_notes TEXT,
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS seo_description TEXT,
  ADD COLUMN IF NOT EXISTS seo_keywords TEXT,
  ADD COLUMN IF NOT EXISTS show_in_calculator BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS calculator_family_id UUID REFERENCES calculator_families (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS calculator_priority INT NOT NULL DEFAULT 0;

UPDATE products SET selling_price = base_price WHERE selling_price IS NULL;

ALTER TABLE inventory
  ADD COLUMN IF NOT EXISTS unit TEXT NOT NULL DEFAULT 'pcs',
  ADD COLUMN IF NOT EXISTS stock_status TEXT NOT NULL DEFAULT 'in_stock';

CREATE OR REPLACE FUNCTION sync_product_selling_base_price()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.selling_price IS NOT NULL THEN
    NEW.base_price := NEW.selling_price;
  ELSIF NEW.base_price IS NOT NULL AND (NEW.selling_price IS NULL OR TG_OP = 'INSERT') THEN
    NEW.selling_price := NEW.base_price;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_sync_prices ON products;
CREATE TRIGGER trg_products_sync_prices
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION sync_product_selling_base_price();

COMMENT ON COLUMN products.base_price IS 'Kept in sync with selling_price for legacy clients';
COMMENT ON COLUMN products.metadata IS 'Optional: gallery_urls, document_urls, datasheet_urls, brochure_urls (JSON arrays)';
