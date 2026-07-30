-- Shop ERP: Product Master vs transaction inventory, FIFO, serial/batch, GST, SEO, purchases, parties, quotations, accounting

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE inventory_valuation_method AS ENUM ('fifo', 'weighted_average');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE inventory_movement_type AS ENUM (
    'purchase_in', 'purchase_return', 'sale_out', 'sale_return',
    'adjustment_in', 'adjustment_out', 'transfer_in', 'transfer_out'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE product_serial_status AS ENUM (
    'in_stock', 'reserved', 'sold', 'returned', 'warranty_claim', 'scrapped'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE shop_quotation_status AS ENUM ('draft', 'sent', 'accepted', 'rejected', 'expired', 'converted');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE ledger_account_type AS ENUM ('asset', 'liability', 'equity', 'income', 'expense');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE journal_source_type AS ENUM ('inventory_receipt', 'shop_order', 'shop_quotation', 'manual');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- SEO columns (Category / SubCategory / Product)
-- ---------------------------------------------------------------------------
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS meta_description TEXT,
  ADD COLUMN IF NOT EXISTS meta_keywords TEXT,
  ADD COLUMN IF NOT EXISTS canonical_url TEXT,
  ADD COLUMN IF NOT EXISTS og_title TEXT,
  ADD COLUMN IF NOT EXISTS og_description TEXT,
  ADD COLUMN IF NOT EXISTS og_image TEXT;

ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS default_gst_percentage NUMERIC(5, 2) NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS seo_title TEXT,
  ADD COLUMN IF NOT EXISTS meta_description TEXT,
  ADD COLUMN IF NOT EXISTS meta_keywords TEXT,
  ADD COLUMN IF NOT EXISTS canonical_url TEXT,
  ADD COLUMN IF NOT EXISTS og_title TEXT,
  ADD COLUMN IF NOT EXISTS og_description TEXT,
  ADD COLUMN IF NOT EXISTS og_image TEXT;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS online_price NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS use_gst_override BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS warranty_months INT,
  ADD COLUMN IF NOT EXISTS track_serial BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS track_batch BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS valuation_method inventory_valuation_method NOT NULL DEFAULT 'fifo',
  ADD COLUMN IF NOT EXISTS url_slug TEXT,
  ADD COLUMN IF NOT EXISTS canonical_url TEXT,
  ADD COLUMN IF NOT EXISTS og_title TEXT,
  ADD COLUMN IF NOT EXISTS og_description TEXT,
  ADD COLUMN IF NOT EXISTS og_image TEXT;

-- Align legacy SEO column names with full SEO set
COMMENT ON COLUMN products.seo_description IS 'Meta description (legacy name)';
COMMENT ON COLUMN products.seo_keywords IS 'Meta keywords (legacy name)';

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_url_slug ON products (url_slug) WHERE url_slug IS NOT NULL AND url_slug <> '';

-- ---------------------------------------------------------------------------
-- GST resolution (subcategory default, product override)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION resolve_product_gst_percentage(p_product_id UUID)
RETURNS NUMERIC AS $$
  SELECT COALESCE(
    CASE WHEN p.use_gst_override THEN p.tax_percentage ELSE NULL END,
    sc.default_gst_percentage,
    p.tax_percentage,
    0
  )
  FROM products p
  JOIN sub_categories sc ON sc.id = p.sub_category_id
  WHERE p.id = p_product_id;
$$ LANGUAGE sql STABLE;

-- ---------------------------------------------------------------------------
-- Parties: suppliers & customers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  contact_name TEXT,
  email TEXT,
  phone TEXT,
  gstin TEXT,
  address JSONB NOT NULL DEFAULT '{}',
  payment_terms TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  gstin TEXT,
  billing_address JSONB NOT NULL DEFAULT '{}',
  shipping_address JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Purchase / inventory receipts (transaction-based stock — never duplicate products)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID REFERENCES suppliers (id) ON DELETE SET NULL,
  purchase_invoice_no TEXT NOT NULL,
  purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
  remarks TEXT,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'posted', 'cancelled')),
  subtotal NUMERIC(14, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
  created_by_uid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (supplier_id, purchase_invoice_no)
);

CREATE INDEX IF NOT EXISTS idx_inventory_receipts_date ON inventory_receipts (purchase_date DESC);

CREATE TABLE IF NOT EXISTS inventory_receipt_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID NOT NULL REFERENCES inventory_receipts (id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK (quantity > 0),
  purchase_rate NUMERIC(12, 2) NOT NULL DEFAULT 0,
  gst_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0,
  gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  mrp NUMERIC(12, 2),
  selling_price NUMERIC(12, 2),
  dealer_price NUMERIC(12, 2),
  distributor_price NUMERIC(12, 2),
  batch_number TEXT,
  remarks TEXT,
  line_total NUMERIC(14, 2) NOT NULL DEFAULT 0,
  is_applied BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_receipt_lines_product ON inventory_receipt_lines (product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_receipt_lines_receipt ON inventory_receipt_lines (receipt_id);

CREATE TABLE IF NOT EXISTS inventory_receipt_serials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_line_id UUID NOT NULL REFERENCES inventory_receipt_lines (id) ON DELETE CASCADE,
  serial_number TEXT NOT NULL,
  UNIQUE (receipt_line_id, serial_number)
);

-- FIFO lots (created from receipt lines)
CREATE TABLE IF NOT EXISTS stock_lots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  receipt_line_id UUID REFERENCES inventory_receipt_lines (id) ON DELETE SET NULL,
  batch_number TEXT,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  qty_received INT NOT NULL CHECK (qty_received > 0),
  qty_remaining INT NOT NULL CHECK (qty_remaining >= 0),
  unit_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
  mrp NUMERIC(12, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_lots_fifo ON stock_lots (product_id, received_at, id);

-- Serial registry (warranty + tracking)
CREATE TABLE IF NOT EXISTS product_serials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  serial_number TEXT NOT NULL,
  receipt_line_id UUID REFERENCES inventory_receipt_lines (id) ON DELETE SET NULL,
  lot_id UUID REFERENCES stock_lots (id) ON DELETE SET NULL,
  status product_serial_status NOT NULL DEFAULT 'in_stock',
  purchased_at DATE,
  warranty_expires_at DATE,
  sold_at TIMESTAMPTZ,
  shop_order_item_id UUID REFERENCES shop_order_items (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (serial_number)
);

CREATE INDEX IF NOT EXISTS idx_product_serials_product ON product_serials (product_id, status);

-- Inventory movement ledger
CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  lot_id UUID REFERENCES stock_lots (id) ON DELETE SET NULL,
  movement_type inventory_movement_type NOT NULL,
  quantity INT NOT NULL CHECK (quantity <> 0),
  unit_cost NUMERIC(12, 2),
  reference_type TEXT,
  reference_id UUID,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_product ON inventory_movements (product_id, created_at DESC);

-- Extend summary inventory (backward compatible with Shop storefront)
ALTER TABLE inventory
  ADD COLUMN IF NOT EXISTS avg_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_purchase_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- Shop quotations (separate from calculator quotations)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shop_quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_number TEXT NOT NULL UNIQUE,
  customer_id UUID REFERENCES customers (id) ON DELETE SET NULL,
  firebase_uid TEXT NOT NULL,
  status shop_quotation_status NOT NULL DEFAULT 'draft',
  valid_until DATE,
  notes TEXT,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shop_quotation_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES shop_quotations (id) ON DELETE CASCADE,
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  label TEXT NOT NULL,
  sku TEXT,
  qty NUMERIC(12, 2) NOT NULL DEFAULT 1 CHECK (qty > 0),
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  gst_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0,
  line_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  sort_order INT NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------------
-- Lightweight accounting (double-entry journal)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ledger_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  account_type ledger_account_type NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_no TEXT NOT NULL UNIQUE,
  entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
  description TEXT,
  source_type journal_source_type NOT NULL DEFAULT 'manual',
  source_id UUID,
  is_posted BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journal_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id UUID NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES ledger_accounts (id) ON DELETE RESTRICT,
  debit NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
  credit NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
  product_id UUID REFERENCES products (id) ON DELETE SET NULL,
  party_supplier_id UUID REFERENCES suppliers (id) ON DELETE SET NULL,
  party_customer_id UUID REFERENCES customers (id) ON DELETE SET NULL,
  CHECK (debit > 0 OR credit > 0)
);

-- Seed default ledger accounts (idempotent)
INSERT INTO ledger_accounts (code, name, account_type) VALUES
  ('1000', 'Inventory Asset', 'asset'),
  ('2000', 'Accounts Payable', 'liability'),
  ('4000', 'Sales Revenue', 'income'),
  ('5000', 'Cost of Goods Sold', 'expense'),
  ('2100', 'GST Input Credit', 'asset'),
  ('2200', 'GST Output Payable', 'liability')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Apply receipt line → lots, serials, inventory summary, movements, optional journal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION recalc_inventory_receipt_totals(p_receipt_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE inventory_receipts r SET
    subtotal = COALESCE((
      SELECT SUM(l.line_total - l.gst_amount) FROM inventory_receipt_lines l WHERE l.receipt_id = p_receipt_id
    ), 0),
    tax_amount = COALESCE((
      SELECT SUM(l.gst_amount) FROM inventory_receipt_lines l WHERE l.receipt_id = p_receipt_id
    ), 0),
    total_amount = COALESCE((
      SELECT SUM(l.line_total) FROM inventory_receipt_lines l WHERE l.receipt_id = p_receipt_id
    ), 0)
  WHERE r.id = p_receipt_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION apply_inventory_receipt_line_core(p_line_id UUID)
RETURNS VOID AS $$
DECLARE
  v_line inventory_receipt_lines%ROWTYPE;
  v_receipt inventory_receipts%ROWTYPE;
  v_lot_id UUID;
  v_gst NUMERIC(5, 2);
  v_warranty_months INT;
  v_serial TEXT;
BEGIN
  SELECT * INTO v_line FROM inventory_receipt_lines WHERE id = p_line_id;
  IF NOT FOUND OR v_line.is_applied THEN
    RETURN;
  END IF;

  SELECT * INTO v_receipt FROM inventory_receipts WHERE id = v_line.receipt_id;
  IF v_receipt.status <> 'posted' THEN
    RETURN;
  END IF;

  v_gst := COALESCE(NULLIF(v_line.gst_percentage, 0), resolve_product_gst_percentage(v_line.product_id));

  INSERT INTO stock_lots (
    product_id, receipt_line_id, batch_number, received_at,
    qty_received, qty_remaining, unit_cost, mrp
  ) VALUES (
    v_line.product_id, v_line.id, v_line.batch_number, COALESCE(v_receipt.purchase_date::timestamptz, now()),
    v_line.quantity, v_line.quantity, v_line.purchase_rate, v_line.mrp
  ) RETURNING id INTO v_lot_id;

  INSERT INTO inventory_movements (
    product_id, lot_id, movement_type, quantity, unit_cost,
    reference_type, reference_id, notes
  ) VALUES (
    v_line.product_id, v_lot_id, 'purchase_in', v_line.quantity, v_line.purchase_rate,
    'inventory_receipt_line', v_line.id, v_line.remarks
  );

  INSERT INTO inventory (product_id, qty_on_hand, avg_cost, last_purchase_at)
  VALUES (v_line.product_id, v_line.quantity, v_line.purchase_rate, now())
  ON CONFLICT (product_id) DO UPDATE SET
    qty_on_hand = inventory.qty_on_hand + EXCLUDED.qty_on_hand,
    avg_cost = CASE
      WHEN inventory.qty_on_hand + EXCLUDED.qty_on_hand <= 0 THEN EXCLUDED.avg_cost
      ELSE (
        (inventory.qty_on_hand * inventory.avg_cost) + (EXCLUDED.qty_on_hand * EXCLUDED.avg_cost)
      ) / (inventory.qty_on_hand + EXCLUDED.qty_on_hand)
    END,
    last_purchase_at = EXCLUDED.last_purchase_at,
    updated_at = now();

  UPDATE products SET
    cost_price = v_line.purchase_rate,
    mrp = COALESCE(v_line.mrp, mrp),
    selling_price = COALESCE(v_line.selling_price, selling_price),
    dealer_price = COALESCE(v_line.dealer_price, dealer_price),
    distributor_price = COALESCE(v_line.distributor_price, distributor_price),
    tax_percentage = CASE WHEN use_gst_override THEN tax_percentage ELSE v_gst END
  WHERE id = v_line.product_id;

  SELECT warranty_months INTO v_warranty_months FROM products WHERE id = v_line.product_id;

  FOR v_serial IN
    SELECT serial_number FROM inventory_receipt_serials WHERE receipt_line_id = v_line.id
  LOOP
    INSERT INTO product_serials (
      product_id, serial_number, receipt_line_id, lot_id, status,
      purchased_at, warranty_expires_at
    ) VALUES (
      v_line.product_id, v_serial, v_line.id, v_lot_id, 'in_stock',
      v_receipt.purchase_date,
      CASE WHEN v_warranty_months IS NOT NULL AND v_warranty_months > 0
        THEN (v_receipt.purchase_date + (v_warranty_months || ' months')::interval)::date
        ELSE NULL END
    );
  END LOOP;

  UPDATE inventory_receipt_lines SET is_applied = true WHERE id = v_line.id;
  PERFORM recalc_inventory_receipt_totals(v_line.receipt_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION apply_inventory_receipt_line()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM apply_inventory_receipt_line_core(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_apply_inventory_receipt_line ON inventory_receipt_lines;
CREATE TRIGGER trg_apply_inventory_receipt_line
  AFTER INSERT ON inventory_receipt_lines
  FOR EACH ROW
  EXECUTE FUNCTION apply_inventory_receipt_line();

-- FIFO consumption helper (for sales / issues)
CREATE OR REPLACE FUNCTION consume_stock_fifo(
  p_product_id UUID,
  p_quantity INT,
  p_movement_type inventory_movement_type DEFAULT 'sale_out',
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
  v_remaining INT := p_quantity;
  v_lot stock_lots%ROWTYPE;
  v_take INT;
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'consume_stock_fifo: quantity must be positive';
  END IF;

  FOR v_lot IN
    SELECT * FROM stock_lots
    WHERE product_id = p_product_id AND qty_remaining > 0
    ORDER BY received_at ASC, id ASC
    FOR UPDATE
  LOOP
    EXIT WHEN v_remaining <= 0;
    v_take := LEAST(v_lot.qty_remaining, v_remaining);
    UPDATE stock_lots SET qty_remaining = qty_remaining - v_take WHERE id = v_lot.id;
    INSERT INTO inventory_movements (
      product_id, lot_id, movement_type, quantity, unit_cost, reference_type, reference_id
    ) VALUES (
      p_product_id, v_lot.id, p_movement_type, -v_take, v_lot.unit_cost, p_reference_type, p_reference_id
    );
    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'Insufficient FIFO stock for product %', p_product_id;
  END IF;

  UPDATE inventory SET
    qty_on_hand = GREATEST(0, qty_on_hand - p_quantity),
    updated_at = now()
  WHERE product_id = p_product_id;

  RETURN p_quantity;
END;
$$ LANGUAGE plpgsql;

-- Post purchase journal (inventory debit, AP credit, GST input)
CREATE OR REPLACE FUNCTION post_inventory_receipt_journal(p_receipt_id UUID)
RETURNS VOID AS $$
DECLARE
  v_rec inventory_receipts%ROWTYPE;
  v_inv UUID;
  v_ap UUID;
  v_gst UUID;
  v_entry_id UUID;
BEGIN
  SELECT * INTO v_rec FROM inventory_receipts WHERE id = p_receipt_id;
  IF v_rec.status <> 'posted' OR v_rec.total_amount <= 0 THEN
    RETURN;
  END IF;

  SELECT id INTO v_inv FROM ledger_accounts WHERE code = '1000' LIMIT 1;
  SELECT id INTO v_ap FROM ledger_accounts WHERE code = '2000' LIMIT 1;
  SELECT id INTO v_gst FROM ledger_accounts WHERE code = '2100' LIMIT 1;

  INSERT INTO journal_entries (entry_no, entry_date, description, source_type, source_id)
  VALUES (
    'PUR-' || LEFT(REPLACE(p_receipt_id::text, '-', ''), 12),
    v_rec.purchase_date,
    'Purchase ' || v_rec.purchase_invoice_no,
    'inventory_receipt',
    p_receipt_id
  )
  ON CONFLICT (entry_no) DO NOTHING
  RETURNING id INTO v_entry_id;

  IF v_entry_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO journal_lines (journal_entry_id, account_id, debit, credit, party_supplier_id)
  VALUES (v_entry_id, v_inv, v_rec.subtotal, 0, v_rec.supplier_id);

  IF v_rec.tax_amount > 0 THEN
    INSERT INTO journal_lines (journal_entry_id, account_id, debit, credit, party_supplier_id)
    VALUES (v_entry_id, v_gst, v_rec.tax_amount, 0, v_rec.supplier_id);
  END IF;

  INSERT INTO journal_lines (journal_entry_id, account_id, debit, credit, party_supplier_id)
  VALUES (v_entry_id, v_ap, 0, v_rec.total_amount, v_rec.supplier_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finalize_inventory_receipt(p_receipt_id UUID)
RETURNS VOID AS $$
DECLARE
  v_line_id UUID;
BEGIN
  UPDATE inventory_receipts SET status = 'posted', updated_at = now()
  WHERE id = p_receipt_id AND status = 'draft';

  FOR v_line_id IN
    SELECT id FROM inventory_receipt_lines
    WHERE receipt_id = p_receipt_id AND NOT is_applied
  LOOP
    PERFORM apply_inventory_receipt_line_core(v_line_id);
  END LOOP;

  PERFORM recalc_inventory_receipt_totals(p_receipt_id);
  PERFORM post_inventory_receipt_journal(p_receipt_id);
END;
$$ LANGUAGE plpgsql;

-- Line totals before insert
CREATE OR REPLACE FUNCTION set_inventory_receipt_line_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_gst NUMERIC(5, 2);
  v_taxable NUMERIC(14, 2);
BEGIN
  v_gst := COALESCE(NULLIF(NEW.gst_percentage, 0), resolve_product_gst_percentage(NEW.product_id));
  NEW.gst_percentage := v_gst;
  v_taxable := NEW.purchase_rate * NEW.quantity;
  NEW.gst_amount := ROUND(v_taxable * v_gst / 100, 2);
  NEW.line_total := v_taxable + NEW.gst_amount;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_receipt_line_totals ON inventory_receipt_lines;
CREATE TRIGGER trg_inventory_receipt_line_totals
  BEFORE INSERT OR UPDATE ON inventory_receipt_lines
  FOR EACH ROW
  EXECUTE FUNCTION set_inventory_receipt_line_totals();

-- updated_at triggers
CREATE TRIGGER trg_suppliers_updated BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_customers_updated BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_inventory_receipts_updated BEFORE UPDATE ON inventory_receipts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_product_serials_updated BEFORE UPDATE ON product_serials FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_shop_quotations_updated BEFORE UPDATE ON shop_quotations FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Reporting views
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_inventory_stock_report AS
SELECT
  p.id AS product_id,
  p.sku,
  p.name AS product_name,
  b.name AS brand_name,
  sc.name AS sub_category_name,
  c.name AS category_name,
  i.qty_on_hand,
  i.qty_reserved,
  i.reorder_level,
  i.avg_cost,
  i.stock_status,
  (i.qty_on_hand * i.avg_cost) AS stock_value,
  COALESCE(lot.open_lots, 0) AS open_fifo_lots,
  COALESCE(ser.serial_in_stock, 0) AS serials_in_stock
FROM products p
JOIN inventory i ON i.product_id = p.id
LEFT JOIN brands b ON b.id = p.brand_id
LEFT JOIN sub_categories sc ON sc.id = p.sub_category_id
LEFT JOIN categories c ON c.id = sc.category_id
LEFT JOIN (
  SELECT product_id, COUNT(*) AS open_lots FROM stock_lots WHERE qty_remaining > 0 GROUP BY product_id
) lot ON lot.product_id = p.id
LEFT JOIN (
  SELECT product_id, COUNT(*) AS serial_in_stock FROM product_serials WHERE status = 'in_stock' GROUP BY product_id
) ser ON ser.product_id = p.id;

CREATE OR REPLACE VIEW v_purchase_register AS
SELECT
  r.id AS receipt_id,
  r.purchase_invoice_no,
  r.purchase_date,
  s.name AS supplier_name,
  p.sku,
  p.name AS product_name,
  l.quantity,
  l.purchase_rate,
  l.gst_percentage,
  l.gst_amount,
  l.line_total,
  l.batch_number
FROM inventory_receipts r
JOIN inventory_receipt_lines l ON l.receipt_id = r.id
JOIN products p ON p.id = l.product_id
LEFT JOIN suppliers s ON s.id = r.supplier_id
WHERE r.status = 'posted'
ORDER BY r.purchase_date DESC, r.created_at DESC;

CREATE OR REPLACE VIEW v_gst_summary AS
SELECT
  date_trunc('month', r.purchase_date)::date AS period_month,
  SUM(l.gst_amount) AS input_gst,
  SUM(l.line_total - l.gst_amount) AS taxable_purchases
FROM inventory_receipts r
JOIN inventory_receipt_lines l ON l.receipt_id = r.id
WHERE r.status = 'posted'
GROUP BY 1;

COMMENT ON TABLE inventory IS 'Stock summary per product; qty updated by inventory_receipt_lines (not duplicate products)';
COMMENT ON TABLE products IS 'Product master (SKU unique); stock added via inventory receipts only';
COMMENT ON TABLE inventory_receipt_lines IS 'Inventory entry lines — increases stock for existing product_id';

-- ---------------------------------------------------------------------------
-- RLS (Shop ERP tables)
-- ---------------------------------------------------------------------------
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_receipt_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_receipt_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_serials ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_quotation_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY suppliers_read ON suppliers FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY suppliers_write ON suppliers FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY customers_read ON customers FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY customers_write ON customers FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY inv_receipts_read ON inventory_receipts FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY inv_receipts_write ON inventory_receipts FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY inv_receipt_lines_read ON inventory_receipt_lines FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY inv_receipt_lines_write ON inventory_receipt_lines FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY inv_receipt_serials_read ON inventory_receipt_serials FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY inv_receipt_serials_write ON inventory_receipt_serials FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY stock_lots_read ON stock_lots FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY stock_lots_write ON stock_lots FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY product_serials_read ON product_serials FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY product_serials_write ON product_serials FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY inv_movements_read ON inventory_movements FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY inv_movements_write ON inventory_movements FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY shop_quotations_read ON shop_quotations FOR SELECT
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());
CREATE POLICY shop_quotations_write ON shop_quotations FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());

CREATE POLICY shop_quotation_lines_read ON shop_quotation_lines FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shop_quotations q
      WHERE q.id = quotation_id AND (q.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  );
CREATE POLICY shop_quotation_lines_write ON shop_quotation_lines FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM shop_quotations q
      WHERE q.id = quotation_id AND (q.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM shop_quotations q
      WHERE q.id = quotation_id AND (q.firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
    )
  );

CREATE POLICY ledger_accounts_read ON ledger_accounts FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY ledger_accounts_write ON ledger_accounts FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY journal_entries_read ON journal_entries FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY journal_entries_write ON journal_entries FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY journal_lines_read ON journal_lines FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY journal_lines_write ON journal_lines FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

GRANT SELECT ON v_inventory_stock_report TO authenticated;
GRANT SELECT ON v_purchase_register TO authenticated;
GRANT SELECT ON v_gst_summary TO authenticated;
