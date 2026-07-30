-- Shared product catalog (Shop + Calculator + Quotations)

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sub_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES categories (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (category_id, slug)
);

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE attribute_data_type AS ENUM ('text', 'number', 'select', 'bool');

CREATE TABLE IF NOT EXISTS attribute_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  data_type attribute_data_type NOT NULL DEFAULT 'text',
  unit TEXT,
  allowed_values JSONB,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS attribute_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS attribute_group_attributes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attribute_group_id UUID NOT NULL REFERENCES attribute_groups (id) ON DELETE CASCADE,
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  sort_order INT NOT NULL DEFAULT 0,
  is_required BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (attribute_group_id, attribute_id)
);

CREATE TABLE IF NOT EXISTS sub_category_attribute_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sub_category_id UUID NOT NULL REFERENCES sub_categories (id) ON DELETE CASCADE,
  attribute_group_id UUID NOT NULL REFERENCES attribute_groups (id) ON DELETE CASCADE,
  UNIQUE (sub_category_id, attribute_group_id)
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sub_category_id UUID NOT NULL REFERENCES sub_categories (id) ON DELETE RESTRICT,
  brand_id UUID REFERENCES brands (id) ON DELETE SET NULL,
  sku TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  base_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_class TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_sub_category ON products (sub_category_id);

CREATE TABLE IF NOT EXISTS product_attributes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  value_text TEXT,
  value_number NUMERIC,
  value_json JSONB,
  UNIQUE (product_id, attribute_id)
);

CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL UNIQUE REFERENCES products (id) ON DELETE CASCADE,
  qty_on_hand INT NOT NULL DEFAULT 0,
  qty_reserved INT NOT NULL DEFAULT 0,
  reorder_level INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-create product_attributes from subcategory attribute groups
CREATE OR REPLACE FUNCTION seed_product_attributes_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO product_attributes (product_id, attribute_id)
  SELECT NEW.id, aga.attribute_id
  FROM sub_category_attribute_groups scag
  JOIN attribute_group_attributes aga ON aga.attribute_group_id = scag.attribute_group_id
  WHERE scag.sub_category_id = NEW.sub_category_id
  ON CONFLICT (product_id, attribute_id) DO NOTHING;

  INSERT INTO inventory (product_id, qty_on_hand, qty_reserved, reorder_level)
  VALUES (NEW.id, 0, 0, 0)
  ON CONFLICT (product_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_seed_attributes ON products;
CREATE TRIGGER trg_products_seed_attributes
  AFTER INSERT ON products
  FOR EACH ROW
  EXECUTE FUNCTION seed_product_attributes_on_insert();

-- updated_at triggers
CREATE TRIGGER trg_categories_updated BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_sub_categories_updated BEFORE UPDATE ON sub_categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_brands_updated BEFORE UPDATE ON brands FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_attribute_master_updated BEFORE UPDATE ON attribute_master FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_attribute_groups_updated BEFORE UPDATE ON attribute_groups FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_platform_users_updated BEFORE UPDATE ON platform_users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
