-- AI Business OS Phase 3: proposal templates, quotation numbering helpers

CREATE TABLE IF NOT EXISTS bos_proposal_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  body_markdown TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (tenant_id, name)
);

ALTER TABLE bos_proposals
  ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES bos_proposal_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS quotation_id UUID REFERENCES bos_quotations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS estimate_id UUID REFERENCES bos_estimates(id) ON DELETE SET NULL;

ALTER TABLE bos_quotations
  ADD COLUMN IF NOT EXISTS valid_until DATE,
  ADD COLUMN IF NOT EXISTS customer_name TEXT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT,
  ADD COLUMN IF NOT EXISTS customer_address TEXT;

ALTER TABLE bos_estimates
  ADD COLUMN IF NOT EXISTS lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS deal_id UUID REFERENCES bos_deals(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft';

INSERT INTO bos_proposal_templates (tenant_id, name, body_markdown, is_default)
VALUES (
  'b0000000-0000-4000-8000-000000000001',
  'standard_services',
  E'# Proposal — {{company}}\n\nDear {{contact}},\n\nThank you for considering **DG.YARD**.\n\n## Understanding\n{{summary}}\n\n## Scope of work\n{{scope}}\n\n## Investment\n{{investment}}\n\n## Next steps\n1. Confirm scope\n2. Site survey / kickoff\n3. Advance & scheduling\n\nWarm regards,  \nDG.YARD Sales\n',
  true
)
ON CONFLICT (tenant_id, name) DO NOTHING;

DROP TRIGGER IF EXISTS trg_bos_proposal_templates_updated ON bos_proposal_templates;
CREATE TRIGGER trg_bos_proposal_templates_updated
  BEFORE UPDATE ON bos_proposal_templates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE bos_proposal_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bos_proposal_templates_tenant_all ON bos_proposal_templates;
CREATE POLICY bos_proposal_templates_tenant_all ON bos_proposal_templates FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));
