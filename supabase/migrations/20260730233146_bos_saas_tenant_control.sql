-- SaaS Multi-Tenant Control Layer (extend bos_* only — no parallel tenants/companies tables)

ALTER TABLE bos_tenants
  ADD COLUMN IF NOT EXISTS gstin TEXT,
  ADD COLUMN IF NOT EXISTS business_type TEXT,
  ADD COLUMN IF NOT EXISTS contact_email TEXT,
  ADD COLUMN IF NOT EXISTS contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS address_line TEXT;

COMMENT ON COLUMN bos_tenants.gstin IS 'Company GSTIN for invoices / SaaS profile';
COMMENT ON COLUMN bos_tenants.business_type IS 'e.g. cctv_integrator, education, retail';

ALTER TABLE bos_tenant_settings
  ADD COLUMN IF NOT EXISTS api_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS api_secrets JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN bos_tenant_settings.api_config IS
  'Non-secret provider config: whatsapp.phone_number_id, sms.sender_id, email.from, voice.number, providers';
COMMENT ON COLUMN bos_tenant_settings.api_secrets IS
  'Sensitive tokens — prefer write via bos-tenant-secrets Edge; members see masked status in UI';

-- Usage metrics index for Super Admin rollups
CREATE INDEX IF NOT EXISTS idx_bos_usage_events_metric_time
  ON bos_usage_events (tenant_id, metric, occurred_at DESC);

-- Ensure occurred_at exists (phase1 may use created_at)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bos_usage_events' AND column_name = 'occurred_at'
  ) THEN
    ALTER TABLE bos_usage_events ADD COLUMN occurred_at TIMESTAMPTZ NOT NULL DEFAULT now();
  END IF;
END $$;
