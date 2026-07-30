-- AI Business OS (bos_*) — multi-tenant foundation + Phase 1–6 schema
-- Identity: firebase_uid (JWT sub). Tenant: bos_tenant_id claim + membership.

-- ── Enums ──────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE bos_tenant_status AS ENUM ('active', 'trial', 'suspended', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_member_role AS ENUM ('owner', 'admin', 'sales', 'agent', 'viewer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_subscription_status AS ENUM ('trialing', 'active', 'past_due', 'suspended', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_lead_source AS ENUM (
    'website', 'whatsapp', 'facebook', 'google', 'api', 'manual', 'csv'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_lead_score AS ENUM ('hot', 'warm', 'cold');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_lead_stage AS ENUM (
    'new', 'contacted', 'qualified', 'proposal', 'negotiation', 'won', 'lost'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_deal_stage AS ENUM (
    'qualification', 'discovery', 'proposal', 'negotiation', 'won', 'lost'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_kb_collection AS ENUM (
    'cctv', 'networking', 'software', 'website', 'mobile_apps',
    'digital_marketing', 'dgyard_services', 'general'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_ticket_status AS ENUM ('open', 'in_progress', 'waiting', 'resolved', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_ticket_priority AS ENUM ('low', 'medium', 'high', 'urgent');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_project_status AS ENUM ('planning', 'active', 'on_hold', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_campaign_status AS ENUM ('draft', 'scheduled', 'running', 'paused', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_message_direction AS ENUM ('inbound', 'outbound');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bos_quote_status AS ENUM ('draft', 'sent', 'accepted', 'rejected', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── JWT claim helpers (no table deps) ──────────────────────────────────────
CREATE OR REPLACE FUNCTION bos_auth_tenant_id()
RETURNS UUID AS $$
  SELECT NULLIF(COALESCE(auth.jwt() ->> 'bos_tenant_id', ''), '')::UUID;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION bos_auth_member_role()
RETURNS TEXT AS $$
  SELECT COALESCE(auth.jwt() ->> 'bos_role', '');
$$ LANGUAGE sql STABLE;

-- ── Plans & Tenants ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  price_monthly_paise INTEGER NOT NULL DEFAULT 0,
  price_yearly_paise INTEGER NOT NULL DEFAULT 0,
  features JSONB NOT NULL DEFAULT '{}'::jsonb,
  limits JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  status bos_tenant_status NOT NULL DEFAULT 'trial',
  plan_id UUID REFERENCES bos_plans(id),
  logo_url TEXT,
  brand_primary TEXT DEFAULT '#0F172A',
  brand_accent TEXT DEFAULT '#2563EB',
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_tenant_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  firebase_uid TEXT NOT NULL,
  role bos_member_role NOT NULL DEFAULT 'viewer',
  display_name TEXT,
  email TEXT,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (tenant_id, firebase_uid)
);

CREATE INDEX IF NOT EXISTS idx_bos_tenant_members_uid ON bos_tenant_members(firebase_uid)
  WHERE deleted_at IS NULL;

-- Membership helpers (after bos_tenant_members exists)
CREATE OR REPLACE FUNCTION bos_is_member(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
  SELECT auth_is_superadmin()
    OR EXISTS (
      SELECT 1 FROM bos_tenant_members m
      WHERE m.tenant_id = p_tenant_id
        AND m.firebase_uid = auth_firebase_uid()
        AND m.deleted_at IS NULL
        AND m.is_active = true
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION bos_tenant_ok(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
  SELECT auth_is_superadmin() OR bos_is_member(p_tenant_id);
$$ LANGUAGE sql STABLE;

CREATE TABLE IF NOT EXISTS bos_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES bos_plans(id),
  status bos_subscription_status NOT NULL DEFAULT 'trialing',
  razorpay_subscription_id TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES bos_subscriptions(id),
  amount_paise INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'draft',
  invoice_number TEXT,
  pdf_url TEXT,
  issued_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  metric TEXT NOT NULL,
  quantity NUMERIC NOT NULL DEFAULT 1,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_tenant_settings (
  tenant_id UUID PRIMARY KEY REFERENCES bos_tenants(id) ON DELETE CASCADE,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  api_keys_placeholder JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES bos_tenants(id) ON DELETE SET NULL,
  firebase_uid TEXT,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── CRM / Leads (Phase 1) ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  industry TEXT,
  website TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  company_id UUID REFERENCES bos_companies(id) ON DELETE SET NULL,
  first_name TEXT,
  last_name TEXT,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  title TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bos_contacts_phone ON bos_contacts(tenant_id, phone)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bos_contacts_email ON bos_contacts(tenant_id, email)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS bos_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  source bos_lead_source NOT NULL DEFAULT 'manual',
  stage bos_lead_stage NOT NULL DEFAULT 'new',
  score bos_lead_score,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  company_name TEXT,
  requirements TEXT,
  ai_summary TEXT,
  ai_next_questions JSONB NOT NULL DEFAULT '[]'::jsonb,
  owner_firebase_uid TEXT,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  company_id UUID REFERENCES bos_companies(id) ON DELETE SET NULL,
  next_follow_up_at TIMESTAMPTZ,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bos_leads_tenant_stage ON bos_leads(tenant_id, stage)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bos_leads_phone ON bos_leads(tenant_id, phone)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bos_leads_email ON bos_leads(tenant_id, email)
  WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS bos_lead_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  lead_id UUID NOT NULL REFERENCES bos_leads(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  body TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_lead_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  lead_id UUID NOT NULL REFERENCES bos_leads(id) ON DELETE CASCADE,
  assignee_firebase_uid TEXT NOT NULL,
  assigned_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  stage bos_deal_stage NOT NULL DEFAULT 'qualification',
  amount_paise INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'INR',
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  company_id UUID REFERENCES bos_companies(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  owner_firebase_uid TEXT,
  expected_close_at DATE,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  subject TEXT,
  body TEXT,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  deal_id UUID REFERENCES bos_deals(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE CASCADE,
  deal_id UUID REFERENCES bos_deals(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE CASCADE,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_pipeline_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  label TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_won BOOLEAN NOT NULL DEFAULT false,
  is_lost BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (tenant_id, code)
);

-- ── Messaging / Campaigns / KB (Phase 2) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  channel TEXT NOT NULL DEFAULT 'whatsapp',
  external_id TEXT,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  last_message_at TIMESTAMPTZ,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES bos_conversations(id) ON DELETE CASCADE,
  direction bos_message_direction NOT NULL,
  body TEXT,
  media_url TEXT,
  status TEXT NOT NULL DEFAULT 'sent',
  external_id TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'whatsapp',
  status bos_campaign_status NOT NULL DEFAULT 'draft',
  template_name TEXT,
  audience_filter JSONB NOT NULL DEFAULT '{}'::jsonb,
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  trigger_voice BOOLEAN NOT NULL DEFAULT false,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_campaign_recipients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  campaign_id UUID NOT NULL REFERENCES bos_campaigns(id) ON DELETE CASCADE,
  phone TEXT,
  email TEXT,
  full_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_kb_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  collection bos_kb_collection NOT NULL DEFAULT 'general',
  title TEXT NOT NULL,
  body TEXT,
  source_url TEXT,
  qdrant_point_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- ── Quotes / Proposals / Estimator (Phase 3) ───────────────────────────────
CREATE TABLE IF NOT EXISTS bos_quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  quote_number TEXT,
  title TEXT,
  status bos_quote_status NOT NULL DEFAULT 'draft',
  deal_id UUID REFERENCES bos_deals(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  company_id UUID REFERENCES bos_companies(id) ON DELETE SET NULL,
  subtotal_paise INTEGER NOT NULL DEFAULT 0,
  tax_paise INTEGER NOT NULL DEFAULT 0,
  total_paise INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'INR',
  notes TEXT,
  boq_meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_quotation_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  quotation_id UUID NOT NULL REFERENCES bos_quotations(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  category TEXT,
  description TEXT NOT NULL,
  qty NUMERIC NOT NULL DEFAULT 1,
  unit TEXT DEFAULT 'nos',
  unit_price_paise INTEGER NOT NULL DEFAULT 0,
  tax_percent NUMERIC NOT NULL DEFAULT 18,
  line_total_paise INTEGER NOT NULL DEFAULT 0,
  product_id UUID,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS bos_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',
  deal_id UUID REFERENCES bos_deals(id) ON DELETE SET NULL,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  body_markdown TEXT,
  pdf_url TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_estimates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  estimate_type TEXT NOT NULL DEFAULT 'website',
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  total_paise INTEGER NOT NULL DEFAULT 0,
  breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  proposal_id UUID REFERENCES bos_proposals(id) ON DELETE SET NULL,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- ── Projects / Tickets (Phase 4) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  status bos_project_status NOT NULL DEFAULT 'planning',
  deal_id UUID REFERENCES bos_deals(id) ON DELETE SET NULL,
  company_id UUID REFERENCES bos_companies(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  owner_firebase_uid TEXT,
  start_date DATE,
  end_date DATE,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_project_milestones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES bos_projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  due_date DATE,
  completed_at TIMESTAMPTZ,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bos_project_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES bos_projects(id) ON DELETE CASCADE,
  milestone_id UUID REFERENCES bos_project_milestones(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'todo',
  assignee_firebase_uid TEXT,
  due_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS bos_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  description TEXT,
  status bos_ticket_status NOT NULL DEFAULT 'open',
  priority bos_ticket_priority NOT NULL DEFAULT 'medium',
  project_id UUID REFERENCES bos_projects(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  assignee_firebase_uid TEXT,
  sla_due_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- ── Voice / Marketing (Phase 5) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_voice_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE SET NULL,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE SET NULL,
  phone TEXT,
  direction TEXT NOT NULL DEFAULT 'outbound',
  status TEXT NOT NULL DEFAULT 'queued',
  provider TEXT,
  external_id TEXT,
  transcript TEXT,
  recording_url TEXT,
  duration_sec INTEGER,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_marketing_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'content',
  status TEXT NOT NULL DEFAULT 'draft',
  brief TEXT,
  generated_content JSONB NOT NULL DEFAULT '{}'::jsonb,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- ── Marketplace (Phase 6) ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_marketplace_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'template',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bos_marketplace_installs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES bos_marketplace_items(id) ON DELETE CASCADE,
  installed_by TEXT,
  installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, item_id)
);

-- ── updated_at triggers ────────────────────────────────────────────────────
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bos_plans','bos_tenants','bos_tenant_members','bos_subscriptions',
    'bos_companies','bos_contacts','bos_leads','bos_deals','bos_notes',
    'bos_conversations','bos_campaigns','bos_kb_documents',
    'bos_quotations','bos_proposals','bos_estimates',
    'bos_projects','bos_tickets','bos_voice_calls','bos_marketing_campaigns'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_updated ON %I; CREATE TRIGGER trg_%s_updated BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
      t, t, t, t
    );
  END LOOP;
END $$;

-- ── Seed plans + DG.YARD tenant ────────────────────────────────────────────
INSERT INTO bos_plans (id, code, name, description, price_monthly_paise, price_yearly_paise, features, limits, sort_order)
VALUES
  ('a0000000-0000-4000-8000-000000000001', 'starter', 'Starter', 'Core CRM & leads', 499900, 4999000,
   '{"modules":["crm","leads","settings"]}'::jsonb, '{"users":5,"leads":1000}'::jsonb, 1),
  ('a0000000-0000-4000-8000-000000000002', 'growth', 'Growth', 'WhatsApp + campaigns + KB', 1499900, 14999000,
   '{"modules":["crm","leads","whatsapp","campaigns","kb"]}'::jsonb, '{"users":25,"leads":10000}'::jsonb, 2),
  ('a0000000-0000-4000-8000-000000000003', 'enterprise', 'Enterprise', 'Full AI Business OS', 4999900, 49999000,
   '{"modules":["all"]}'::jsonb, '{"users":-1,"leads":-1}'::jsonb, 3)
ON CONFLICT (code) DO NOTHING;

INSERT INTO bos_tenants (id, name, slug, status, plan_id, brand_primary, brand_accent, settings)
VALUES (
  'b0000000-0000-4000-8000-000000000001',
  'DG.YARD',
  'dgyard',
  'active',
  'a0000000-0000-4000-8000-000000000003',
  '#0F172A',
  '#2563EB',
  '{"is_platform_owner": true}'::jsonb
)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO bos_tenant_settings (tenant_id, settings)
VALUES ('b0000000-0000-4000-8000-000000000001', '{"timezone":"Asia/Kolkata","currency":"INR"}'::jsonb)
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO bos_subscriptions (tenant_id, plan_id, status, current_period_start, current_period_end)
SELECT 'b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'active', now(), now() + interval '1 year'
WHERE NOT EXISTS (
  SELECT 1 FROM bos_subscriptions WHERE tenant_id = 'b0000000-0000-4000-8000-000000000001'
);

INSERT INTO bos_pipeline_stages (tenant_id, code, label, sort_order, is_won, is_lost)
VALUES
  ('b0000000-0000-4000-8000-000000000001', 'qualification', 'Qualification', 1, false, false),
  ('b0000000-0000-4000-8000-000000000001', 'discovery', 'Discovery', 2, false, false),
  ('b0000000-0000-4000-8000-000000000001', 'proposal', 'Proposal', 3, false, false),
  ('b0000000-0000-4000-8000-000000000001', 'negotiation', 'Negotiation', 4, false, false),
  ('b0000000-0000-4000-8000-000000000001', 'won', 'Won', 5, true, false),
  ('b0000000-0000-4000-8000-000000000001', 'lost', 'Lost', 6, false, true)
ON CONFLICT (tenant_id, code) DO NOTHING;

INSERT INTO bos_marketplace_items (code, name, description, category, payload)
VALUES
  ('kb-cctv-starter', 'CCTV Knowledge Pack', 'Starter KB for CCTV sales', 'kb', '{"collection":"cctv"}'::jsonb),
  ('wa-followup-templates', 'WhatsApp Follow-up Templates', 'Default WA templates', 'template', '{}'::jsonb),
  ('boq-cctv-rules', 'CCTV BOQ Rules Pack', 'Default BOQ categories', 'template', '{"type":"boq"}'::jsonb)
ON CONFLICT (code) DO NOTHING;

-- Map existing superadmins as DG.YARD owners
INSERT INTO bos_tenant_members (tenant_id, firebase_uid, role, display_name)
SELECT
  'b0000000-0000-4000-8000-000000000001',
  pu.firebase_uid,
  'owner'::bos_member_role,
  COALESCE(pu.phone, pu.firebase_uid)
FROM platform_users pu
WHERE pu.role_mirror = 'superadmin'
ON CONFLICT (tenant_id, firebase_uid) DO NOTHING;

-- ── RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE bos_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_tenant_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_usage_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_lead_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_lead_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_pipeline_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_campaign_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_kb_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_quotation_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_project_milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_project_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_voice_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_marketing_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_marketplace_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_marketplace_installs ENABLE ROW LEVEL SECURITY;

-- Plans: authenticated read; superadmin write
DROP POLICY IF EXISTS bos_plans_read ON bos_plans;
CREATE POLICY bos_plans_read ON bos_plans FOR SELECT TO authenticated
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
DROP POLICY IF EXISTS bos_plans_write ON bos_plans;
CREATE POLICY bos_plans_write ON bos_plans FOR ALL TO authenticated
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

-- Marketplace catalog: authenticated read; superadmin write
DROP POLICY IF EXISTS bos_marketplace_items_read ON bos_marketplace_items;
CREATE POLICY bos_marketplace_items_read ON bos_marketplace_items FOR SELECT TO authenticated
  USING (is_active OR auth_is_superadmin());
DROP POLICY IF EXISTS bos_marketplace_items_write ON bos_marketplace_items;
CREATE POLICY bos_marketplace_items_write ON bos_marketplace_items FOR ALL TO authenticated
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

-- Tenants: members see own; superadmin all
DROP POLICY IF EXISTS bos_tenants_select ON bos_tenants;
CREATE POLICY bos_tenants_select ON bos_tenants FOR SELECT TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(id));
DROP POLICY IF EXISTS bos_tenants_write ON bos_tenants;
CREATE POLICY bos_tenants_write ON bos_tenants FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(id));

-- Members
DROP POLICY IF EXISTS bos_tenant_members_select ON bos_tenant_members;
CREATE POLICY bos_tenant_members_select ON bos_tenant_members FOR SELECT TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id) OR firebase_uid = auth_firebase_uid());
DROP POLICY IF EXISTS bos_tenant_members_write ON bos_tenant_members;
CREATE POLICY bos_tenant_members_write ON bos_tenant_members FOR ALL TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id))
  WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id));

-- Generic tenant-scoped policy helper via dynamic SQL
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bos_subscriptions','bos_invoices','bos_usage_events','bos_tenant_settings','bos_audit_log',
    'bos_companies','bos_contacts','bos_leads','bos_lead_activities','bos_lead_assignments',
    'bos_deals','bos_activities','bos_notes','bos_pipeline_stages',
    'bos_conversations','bos_messages','bos_campaigns','bos_campaign_recipients','bos_kb_documents',
    'bos_quotations','bos_quotation_lines','bos_proposals','bos_estimates',
    'bos_projects','bos_project_milestones','bos_project_tasks','bos_tickets',
    'bos_voice_calls','bos_marketing_campaigns','bos_marketplace_installs'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_tenant_all ON %I', t, t);
    EXECUTE format(
      'CREATE POLICY %I_tenant_all ON %I FOR ALL TO authenticated
         USING (auth_is_superadmin() OR bos_is_member(tenant_id))
         WITH CHECK (auth_is_superadmin() OR bos_is_member(tenant_id))',
      t, t
    );
  END LOOP;
END $$;
