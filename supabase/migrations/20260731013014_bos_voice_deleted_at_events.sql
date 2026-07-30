-- Soft-delete + webhook event log for AI voice calls
ALTER TABLE bos_voice_calls
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_bos_voice_calls_tenant_deleted
  ON bos_voice_calls (tenant_id)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS bos_voice_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  call_id UUID REFERENCES bos_voice_calls(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  provider TEXT,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bos_voice_events_tenant_created
  ON bos_voice_events (tenant_id, created_at DESC);

ALTER TABLE bos_voice_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bos_voice_events_tenant_all ON bos_voice_events;
CREATE POLICY bos_voice_events_tenant_all ON bos_voice_events FOR ALL TO authenticated
  USING (bos_is_member(tenant_id))
  WITH CHECK (bos_is_member(tenant_id));
