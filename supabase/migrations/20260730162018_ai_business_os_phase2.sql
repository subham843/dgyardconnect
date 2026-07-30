-- AI Business OS Phase 2: WhatsApp templates, opt-outs, KB chunks, campaign run metadata

CREATE TABLE IF NOT EXISTS bos_wa_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  body TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'en',
  meta_template_name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS bos_opt_outs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'whatsapp',
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, phone, channel)
);

CREATE TABLE IF NOT EXISTS bos_kb_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES bos_kb_documents(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL DEFAULT 0,
  content TEXT NOT NULL,
  qdrant_point_id TEXT,
  embedding_status TEXT NOT NULL DEFAULT 'pending',
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_bos_kb_chunks_doc ON bos_kb_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_bos_opt_outs_phone ON bos_opt_outs(tenant_id, phone);

ALTER TABLE bos_campaigns
  ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES bos_wa_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS message_body TEXT,
  ADD COLUMN IF NOT EXISTS sent_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS failed_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS skipped_opt_out INTEGER NOT NULL DEFAULT 0;

ALTER TABLE bos_conversations
  ADD COLUMN IF NOT EXISTS ai_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS unread_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE bos_campaign_recipients
  ADD COLUMN IF NOT EXISTS sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS error TEXT;

ALTER TABLE bos_kb_documents
  ADD COLUMN IF NOT EXISTS reindex_status TEXT NOT NULL DEFAULT 'idle',
  ADD COLUMN IF NOT EXISTS last_reindexed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS chunk_count INTEGER NOT NULL DEFAULT 0;

-- Seed default WA templates for DG.YARD
INSERT INTO bos_wa_templates (tenant_id, name, body, language, meta_template_name)
VALUES
  (
    'b0000000-0000-4000-8000-000000000001',
    'followup_intro',
    'Hi {{name}}, thanks for contacting DG.YARD. How can we help with CCTV / networking / software today?',
    'en',
    'dgyard_followup_intro'
  ),
  (
    'b0000000-0000-4000-8000-000000000001',
    'quote_ready',
    'Hi {{name}}, your quotation is ready. Reply YES to schedule a site survey.',
    'en',
    'dgyard_quote_ready'
  )
ON CONFLICT (tenant_id, name) DO NOTHING;

DROP TRIGGER IF EXISTS trg_bos_wa_templates_updated ON bos_wa_templates;
CREATE TRIGGER trg_bos_wa_templates_updated
  BEFORE UPDATE ON bos_wa_templates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE bos_wa_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_opt_outs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_kb_chunks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bos_wa_templates_tenant_all ON bos_wa_templates;
CREATE POLICY bos_wa_templates_tenant_all ON bos_wa_templates FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));

DROP POLICY IF EXISTS bos_opt_outs_tenant_all ON bos_opt_outs;
CREATE POLICY bos_opt_outs_tenant_all ON bos_opt_outs FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));

DROP POLICY IF EXISTS bos_kb_chunks_tenant_all ON bos_kb_chunks;
CREATE POLICY bos_kb_chunks_tenant_all ON bos_kb_chunks FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));
