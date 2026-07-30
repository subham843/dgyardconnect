-- Phase C: GST fields on SaaS invoices + payment metadata helpers

ALTER TABLE bos_invoices
  ADD COLUMN IF NOT EXISTS taxable_paise INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cgst_paise INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sgst_paise INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS igst_paise INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gst_rate_pct NUMERIC(5,2) NOT NULL DEFAULT 18,
  ADD COLUMN IF NOT EXISTS place_of_supply TEXT,
  ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT,
  ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;

CREATE INDEX IF NOT EXISTS idx_bos_invoices_razorpay_order
  ON bos_invoices (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bos_usage_events_tenant_metric
  ON bos_usage_events (tenant_id, metric, occurred_at DESC);

COMMENT ON COLUMN bos_invoices.taxable_paise IS 'Pre-GST SaaS subscription amount in paise';
COMMENT ON COLUMN bos_invoices.gst_rate_pct IS 'GST rate applied (default 18%)';
