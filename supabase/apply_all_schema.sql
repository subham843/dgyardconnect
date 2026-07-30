-- Platform identity (Firebase UID bridge)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS platform_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL UNIQUE,
  phone TEXT,
  display_name TEXT,
  role_mirror TEXT NOT NULL DEFAULT 'user',
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_platform_users_firebase_uid ON platform_users (firebase_uid);

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  action TEXT NOT NULL,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
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
-- Shop commerce tables

CREATE TYPE shop_order_status AS ENUM (
  'draft', 'pending_payment', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'
);

CREATE TABLE IF NOT EXISTS shop_carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_shop_carts_active_uid
  ON shop_carts (firebase_uid) WHERE is_active = true;

CREATE TABLE IF NOT EXISTS shop_cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id UUID NOT NULL REFERENCES shop_carts (id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
  qty INT NOT NULL DEFAULT 1 CHECK (qty > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS shop_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  status shop_order_status NOT NULL DEFAULT 'pending_payment',
  shipping_address JSONB,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  payment_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shop_orders_uid ON shop_orders (firebase_uid);

CREATE TABLE IF NOT EXISTS shop_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES shop_orders (id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
  product_name TEXT NOT NULL,
  sku TEXT NOT NULL,
  unit_price NUMERIC(12, 2) NOT NULL,
  qty INT NOT NULL CHECK (qty > 0),
  line_total NUMERIC(12, 2) NOT NULL
);

CREATE TRIGGER trg_shop_carts_updated BEFORE UPDATE ON shop_carts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_shop_cart_items_updated BEFORE UPDATE ON shop_cart_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_shop_orders_updated BEFORE UPDATE ON shop_orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Calculator no-code engine + quotations

CREATE TYPE calculator_rule_type AS ENUM (
  'suggest', 'formula', 'visibility', 'dependency', 'recommendation'
);

CREATE TYPE quotation_status AS ENUM ('draft', 'sent', 'accepted', 'rejected', 'expired');

CREATE TABLE IF NOT EXISTS calculator_families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  description TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS calculator_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  is_published BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (family_id, slug, version)
);

CREATE TABLE IF NOT EXISTS calculator_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE CASCADE,
  question_key TEXT NOT NULL,
  label TEXT NOT NULL,
  ui_type TEXT NOT NULL DEFAULT 'number',
  options JSONB,
  sort_order INT NOT NULL DEFAULT 0,
  default_visibility BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (template_id, question_key)
);

CREATE TABLE IF NOT EXISTS calculator_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE CASCADE,
  rule_type calculator_rule_type NOT NULL,
  name TEXT,
  priority INT NOT NULL DEFAULT 100,
  condition JSONB NOT NULL DEFAULT '{}',
  action JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_calculator_rules_template ON calculator_rules (template_id, priority);

CREATE TABLE IF NOT EXISTS calculator_rule_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID NOT NULL REFERENCES calculator_rules (id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  default_qty INT NOT NULL DEFAULT 1,
  UNIQUE (rule_id, product_id)
);

CREATE TABLE IF NOT EXISTS calculator_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  template_id UUID NOT NULL REFERENCES calculator_templates (id) ON DELETE CASCADE,
  answers JSONB NOT NULL DEFAULT '{}',
  result JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  session_id UUID REFERENCES calculator_sessions (id) ON DELETE SET NULL,
  template_id UUID REFERENCES calculator_templates (id) ON DELETE SET NULL,
  status quotation_status NOT NULL DEFAULT 'draft',
  customer_name TEXT,
  customer_address TEXT,
  customer_phone TEXT,
  notes TEXT,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quotation_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES quotations (id) ON DELETE CASCADE,
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  line_type TEXT NOT NULL DEFAULT 'product',
  label TEXT NOT NULL,
  sku TEXT,
  qty NUMERIC(12, 2) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  source_rule_id UUID REFERENCES calculator_rules (id) ON DELETE SET NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TRIGGER trg_calculator_families_updated BEFORE UPDATE ON calculator_families FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_templates_updated BEFORE UPDATE ON calculator_templates FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_questions_updated BEFORE UPDATE ON calculator_questions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_rules_updated BEFORE UPDATE ON calculator_rules FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_calculator_sessions_updated BEFORE UPDATE ON calculator_sessions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_quotations_updated BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- Row Level Security (JWT sub = firebase_uid, role claim = superadmin | user)

ALTER TABLE platform_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE sub_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE attribute_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE attribute_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE attribute_group_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE sub_category_attribute_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_attributes ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_families ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_rule_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE calculator_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_lines ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION auth_firebase_uid()
RETURNS TEXT AS $$
  SELECT COALESCE(auth.jwt() ->> 'sub', '');
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION auth_is_superadmin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    auth.jwt() ->> 'app_role',
    auth.jwt() -> 'user_metadata' ->> 'app_role',
    ''
  ) = 'superadmin';
$$ LANGUAGE sql STABLE;

-- platform_users
CREATE POLICY platform_users_select_own ON platform_users
  FOR SELECT USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());
CREATE POLICY platform_users_insert_own ON platform_users
  FOR INSERT WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());
CREATE POLICY platform_users_update_own ON platform_users
  FOR UPDATE USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

-- Catalog: read authenticated, write superadmin
CREATE POLICY catalog_read ON categories FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY catalog_write ON categories FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY sub_cat_read ON sub_categories FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY sub_cat_write ON sub_categories FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY brands_read ON brands FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY brands_write ON brands FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY attr_master_read ON attribute_master FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY attr_master_write ON attribute_master FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY attr_groups_read ON attribute_groups FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY attr_groups_write ON attribute_groups FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY aga_read ON attribute_group_attributes FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY aga_write ON attribute_group_attributes FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY scag_read ON sub_category_attribute_groups FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY scag_write ON sub_category_attribute_groups FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY products_read ON products FOR SELECT USING ((is_active = true AND auth_firebase_uid() <> '') OR auth_is_superadmin());
CREATE POLICY products_write ON products FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY pa_read ON product_attributes FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY pa_write ON product_attributes FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY pi_read ON product_images FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY pi_write ON product_images FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY inv_read ON inventory FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY inv_write ON inventory FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

-- Shop: owner or superadmin
CREATE POLICY shop_carts_owner ON shop_carts FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

CREATE POLICY shop_cart_items_owner ON shop_cart_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM shop_carts c
      WHERE c.id = cart_id AND (c.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shop_carts c
      WHERE c.id = cart_id AND (c.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  );

CREATE POLICY shop_orders_owner ON shop_orders FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

CREATE POLICY shop_order_items_owner ON shop_order_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM shop_orders o
      WHERE o.id = order_id AND (o.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shop_orders o
      WHERE o.id = order_id AND (o.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  );

-- Calculator: published read for users, full admin write
CREATE POLICY calc_families_read ON calculator_families FOR SELECT
  USING (is_active = true AND auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY calc_families_write ON calculator_families FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY calc_templates_read ON calculator_templates FOR SELECT
  USING (((is_published = true AND is_active = true) AND auth_firebase_uid() <> '') OR auth_is_superadmin());
CREATE POLICY calc_templates_write ON calculator_templates FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY calc_questions_read ON calculator_questions FOR SELECT
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY calc_questions_write ON calculator_questions FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY calc_rules_read ON calculator_rules FOR SELECT
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY calc_rules_write ON calculator_rules FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY calc_rule_products_read ON calculator_rule_products FOR SELECT
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY calc_rule_products_write ON calculator_rule_products FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY calc_sessions_owner ON calculator_sessions FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

CREATE POLICY quotations_owner ON quotations FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

CREATE POLICY quotation_lines_owner ON quotation_lines FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM quotations q
      WHERE q.id = quotation_id AND (q.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM quotations q
      WHERE q.id = quotation_id AND (q.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  );

CREATE POLICY admin_audit_superadmin ON admin_audit_log FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());
-- Seed HD CCTV and IP CCTV calculator families (catalog products added separately by admin)

INSERT INTO calculator_families (name, slug, description, sort_order)
VALUES
  ('HD CCTV', 'hd-cctv', 'Analog HD camera systems', 1),
  ('IP CCTV', 'ip-cctv', 'Network IP camera systems', 2)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO calculator_templates (family_id, name, slug, version, is_published)
SELECT f.id, 'HD CCTV Standard', 'hd-cctv-standard', 1, true
FROM calculator_families f WHERE f.slug = 'hd-cctv'
ON CONFLICT DO NOTHING;

INSERT INTO calculator_templates (family_id, name, slug, version, is_published)
SELECT f.id, 'IP CCTV Standard', 'ip-cctv-standard', 1, true
FROM calculator_families f WHERE f.slug = 'ip-cctv'
ON CONFLICT DO NOTHING;

-- HD CCTV questions
INSERT INTO calculator_questions (template_id, question_key, label, ui_type, options, sort_order)
SELECT t.id, q.key, q.label, q.ui_type, q.options::jsonb, q.sort_order
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'hd-cctv'
CROSS JOIN (VALUES
  ('camera_qty', 'Camera Quantity', 'number', NULL, 1),
  ('resolution', 'Resolution', 'select', '["2MP","4MP","5MP","8MP"]', 2),
  ('storage_days', 'Storage Days', 'number', NULL, 3)
) AS q(key, label, ui_type, options, sort_order)
WHERE t.slug = 'hd-cctv-standard'
ON CONFLICT (template_id, question_key) DO NOTHING;

-- IP CCTV questions
INSERT INTO calculator_questions (template_id, question_key, label, ui_type, options, sort_order)
SELECT t.id, q.key, q.label, q.ui_type, q.options::jsonb, q.sort_order
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'ip-cctv'
CROSS JOIN (VALUES
  ('camera_qty', 'Camera Quantity', 'number', NULL, 1),
  ('resolution', 'Resolution', 'select', '["2MP","4MP","5MP","8MP"]', 2)
) AS q(key, label, ui_type, options, sort_order)
WHERE t.slug = 'ip-cctv-standard'
ON CONFLICT (template_id, question_key) DO NOTHING;

-- HD CCTV rules (product suggestions require admin-linked products)
INSERT INTO calculator_rules (template_id, rule_type, name, priority, condition, action)
SELECT t.id, r.rule_type::calculator_rule_type, r.name, r.priority, r.condition::jsonb, r.action::jsonb
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'hd-cctv'
CROSS JOIN (VALUES
  ('suggest', 'Suggest DVR', 10, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"dvr"},"qty_var":"camera_qty"}'),
  ('suggest', 'Suggest SMPS', 20, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"smps"},"qty_formula":"1"}'),
  ('suggest', 'Suggest HDD', 30, '{"all":[{"var":"storage_days","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"hdd"},"qty_formula":"1"}'),
  ('formula', 'BNC quantity', 40, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"bnc_qty","expression":"camera_qty * 2"}'),
  ('formula', 'DC Connector quantity', 50, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"dc_connector_qty","expression":"camera_qty"}')
) AS r(rule_type, name, priority, condition, action)
WHERE t.slug = 'hd-cctv-standard';

INSERT INTO calculator_rules (template_id, rule_type, name, priority, condition, action)
SELECT t.id, r.rule_type::calculator_rule_type, r.name, r.priority, r.condition::jsonb, r.action::jsonb
FROM calculator_templates t
JOIN calculator_families f ON f.id = t.family_id AND f.slug = 'ip-cctv'
CROSS JOIN (VALUES
  ('suggest', 'Suggest NVR', 10, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"nvr"},"qty_var":"camera_qty"}'),
  ('suggest', 'Suggest POE Switch', 20, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"poe-switch"},"qty_formula":"1"}'),
  ('suggest', 'Suggest HDD', 30, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"suggest_product","match":{"sub_category_slug":"hdd"},"qty_formula":"1"}'),
  ('formula', 'Cat6 quantity', 40, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"cat6_qty","expression":"camera_qty * 50"}'),
  ('formula', 'RJ45 quantity', 50, '{"all":[{"var":"camera_qty","op":"gte","value":1}]}', '{"type":"formula","output_key":"rj45_qty","expression":"camera_qty * 2"}')
) AS r(rule_type, name, priority, condition, action)
WHERE t.slug = 'ip-cctv-standard';

-- === 008_attribute_master_upgrade (also in migrations/008_attribute_master_upgrade.sql) ===
ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'long_text';
ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'multi_select';
ALTER TYPE attribute_data_type ADD VALUE IF NOT EXISTS 'date';

ALTER TABLE attribute_master
  ADD COLUMN IF NOT EXISTS is_required BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS use_in_filter BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS use_in_calculator BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS attribute_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attribute_id UUID NOT NULL REFERENCES attribute_master (id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attribute_options_attribute ON attribute_options (attribute_id, sort_order);
CREATE TRIGGER trg_attribute_options_updated BEFORE UPDATE ON attribute_options FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO attribute_options (attribute_id, label, sort_order, is_active)
SELECT am.id, opt.value::text, (opt.ordinality - 1)::int, true
FROM attribute_master am
CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(am.allowed_values, '[]'::jsonb)) WITH ORDINALITY AS opt(value, ordinality)
WHERE am.data_type::text IN ('select', 'multi_select')
  AND jsonb_array_length(COALESCE(am.allowed_values, '[]'::jsonb)) > 0
  AND NOT EXISTS (SELECT 1 FROM attribute_options ao WHERE ao.attribute_id = am.id);

ALTER TABLE attribute_options ENABLE ROW LEVEL SECURITY;
CREATE POLICY attribute_options_read ON attribute_options FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY attribute_options_write ON attribute_options FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

-- Product ↔ calculator families (many-to-many)
CREATE TABLE IF NOT EXISTS product_calculator_families (
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES calculator_families (id) ON DELETE CASCADE,
  priority INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, family_id)
);
CREATE INDEX IF NOT EXISTS idx_pcf_family ON product_calculator_families (family_id);
ALTER TABLE product_calculator_families ENABLE ROW LEVEL SECURITY;
