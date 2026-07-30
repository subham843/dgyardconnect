-- Omnichannel AI Sales + Marketing MVP (bos_* only)
-- Conversations: web|app|facebook|instagram|whatsapp
-- Campaigns: whatsapp|sms|email + segments
-- Outbound events for delivery/open/click analytics

COMMENT ON COLUMN bos_conversations.channel IS
  'whatsapp | web | app | facebook | instagram';

ALTER TABLE bos_campaigns
  ADD COLUMN IF NOT EXISTS segment JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN bos_campaigns.channel IS
  'whatsapp | sms | email';
COMMENT ON COLUMN bos_campaigns.segment IS
  'Audience preset e.g. {"preset":"hot"|"warm"|"cold"|"new_leads"|"converted"}';

ALTER TABLE bos_wa_templates
  ADD COLUMN IF NOT EXISTS channel TEXT NOT NULL DEFAULT 'whatsapp';

COMMENT ON COLUMN bos_wa_templates.channel IS
  'whatsapp | sms | email — UI label: Message templates';

ALTER TABLE bos_campaign_recipients
  ADD COLUMN IF NOT EXISTS delivery_status TEXT;

COMMENT ON COLUMN bos_campaign_recipients.delivery_status IS
  'queued | sent | sent_sim | delivered | failed | opened | clicked | replied';

ALTER TABLE bos_opt_outs
  ADD COLUMN IF NOT EXISTS email TEXT;

CREATE INDEX IF NOT EXISTS idx_bos_opt_outs_email
  ON bos_opt_outs (tenant_id, lower(email))
  WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_bos_conversations_channel
  ON bos_conversations (tenant_id, channel)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_bos_campaigns_channel
  ON bos_campaigns (tenant_id, channel)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS bos_outbound_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES bos_campaigns(id) ON DELETE SET NULL,
  recipient_id UUID REFERENCES bos_campaign_recipients(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES bos_conversations(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  channel TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bos_outbound_events_tenant_created
  ON bos_outbound_events (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bos_outbound_events_campaign
  ON bos_outbound_events (campaign_id, event_type)
  WHERE campaign_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bos_outbound_events_channel
  ON bos_outbound_events (tenant_id, channel, event_type);

ALTER TABLE bos_outbound_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bos_outbound_events_tenant_all ON bos_outbound_events;
CREATE POLICY bos_outbound_events_tenant_all ON bos_outbound_events FOR ALL TO authenticated
  USING (bos_tenant_ok(tenant_id))
  WITH CHECK (bos_tenant_ok(tenant_id));

-- Seed SMS / Email template examples for default tenant
INSERT INTO bos_wa_templates (tenant_id, name, body, language, channel, meta_template_name)
VALUES
  (
    'b0000000-0000-4000-8000-000000000001',
    'sms_payment_reminder',
    'Hi {{name}}, DG.YARD reminder: payment/service due soon. Reply YES to schedule.',
    'en',
    'sms',
    NULL
  ),
  (
    'b0000000-0000-4000-8000-000000000001',
    'email_welcome',
    'Hi {{name}},\n\nWelcome to DG.YARD. We help with CCTV, networking, and software.\nReply to this email with your site details for a free survey.\n\n— DG.YARD',
    'en',
    'email',
    NULL
  )
ON CONFLICT (tenant_id, name) DO NOTHING;
