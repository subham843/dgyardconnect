-- Row Level Security (JWT sub = firebase_uid, app_role claim = superadmin | user; JWT role = authenticated)

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
