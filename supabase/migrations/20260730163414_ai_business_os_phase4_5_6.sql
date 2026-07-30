-- AI Business OS Phases 4–6: delivery, voice/marketing, SaaS packaging

ALTER TABLE bos_tickets
  ADD COLUMN IF NOT EXISTS sla_hours INTEGER NOT NULL DEFAULT 24;

ALTER TABLE bos_voice_calls
  ADD COLUMN IF NOT EXISTS script TEXT,
  ADD COLUMN IF NOT EXISTS outcome TEXT,
  ADD COLUMN IF NOT EXISTS crm_updated BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE bos_marketing_campaigns
  ADD COLUMN IF NOT EXISTS target_audience TEXT,
  ADD COLUMN IF NOT EXISTS tone TEXT DEFAULT 'professional';

CREATE TABLE IF NOT EXISTS bos_ticket_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  ticket_id UUID NOT NULL REFERENCES bos_tickets(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE bos_ticket_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bos_ticket_comments_tenant_all ON bos_ticket_comments;
CREATE POLICY bos_ticket_comments_tenant_all ON bos_ticket_comments FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));

-- Seed a sample invoice for DG.YARD if none
INSERT INTO bos_invoices (tenant_id, amount_paise, currency, status, invoice_number, issued_at, paid_at)
SELECT
  'b0000000-0000-4000-8000-000000000001',
  4999900,
  'INR',
  'paid',
  'INV-DGYARD-001',
  now() - interval '30 days',
  now() - interval '28 days'
WHERE NOT EXISTS (
  SELECT 1 FROM bos_invoices WHERE tenant_id = 'b0000000-0000-4000-8000-000000000001'
);
