-- Online price is primary customer price; sync legacy base_price/selling_price from it.

ALTER TABLE inventory_receipt_lines
  ADD COLUMN IF NOT EXISTS online_price NUMERIC(12, 2);

UPDATE inventory_receipt_lines
SET online_price = selling_price
WHERE online_price IS NULL AND selling_price IS NOT NULL;

UPDATE products
SET online_price = COALESCE(online_price, selling_price, base_price)
WHERE online_price IS NULL;

CREATE OR REPLACE FUNCTION sync_product_retail_prices()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.online_price IS NOT NULL AND NEW.online_price > 0 THEN
    NEW.selling_price := NEW.online_price;
    NEW.base_price := NEW.online_price;
  ELSIF NEW.selling_price IS NOT NULL AND NEW.selling_price > 0 THEN
    IF NEW.online_price IS NULL OR NEW.online_price = 0 THEN
      NEW.online_price := NEW.selling_price;
    END IF;
    NEW.base_price := NEW.selling_price;
  ELSIF NEW.base_price IS NOT NULL AND NEW.base_price > 0 THEN
    IF NEW.online_price IS NULL OR NEW.online_price = 0 THEN
      NEW.online_price := NEW.base_price;
    END IF;
    IF NEW.selling_price IS NULL OR NEW.selling_price = 0 THEN
      NEW.selling_price := NEW.base_price;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_sync_prices ON products;
CREATE TRIGGER trg_products_sync_prices
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION sync_product_retail_prices();

COMMENT ON COLUMN products.online_price IS 'Customer shop price; drives base_price/selling_price via trigger';
COMMENT ON COLUMN products.selling_price IS 'Legacy sync — same as online_price';
COMMENT ON COLUMN products.base_price IS 'Legacy sync — same as online_price';

CREATE OR REPLACE FUNCTION apply_inventory_receipt_line_core(p_line_id UUID)
RETURNS VOID AS $$
DECLARE
  v_line inventory_receipt_lines%ROWTYPE;
  v_receipt inventory_receipts%ROWTYPE;
  v_lot_id UUID;
  v_gst NUMERIC(5, 2);
  v_warranty_months INT;
  v_serial TEXT;
  v_online NUMERIC(12, 2);
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
  v_online := COALESCE(v_line.online_price, v_line.selling_price);

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
    online_price = COALESCE(v_online, online_price),
    selling_price = COALESCE(v_online, selling_price),
    base_price = COALESCE(v_online, base_price),
    dealer_price = COALESCE(v_line.dealer_price, dealer_price),
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

  UPDATE inventory_receipt_lines SET is_applied = true WHERE id = p_line_id;
  PERFORM recalc_inventory_receipt_totals(v_line.receipt_id);
END;
$$ LANGUAGE plpgsql;
