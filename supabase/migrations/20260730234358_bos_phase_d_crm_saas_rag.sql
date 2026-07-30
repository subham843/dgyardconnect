-- Phase D CRM + SaaS harden + RAG foundations (extend bos_* only)

-- ── Deal stages as free text (configurable pipeline) ─────────────────────
ALTER TABLE bos_deals
  ALTER COLUMN stage TYPE TEXT USING stage::text;
ALTER TABLE bos_deals
  ALTER COLUMN stage SET DEFAULT 'qualification';

COMMENT ON COLUMN bos_deals.stage IS
  'Pipeline stage code matching bos_pipeline_stages.code (text, not enum)';

-- ── CRM attachments ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bos_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  lead_id UUID REFERENCES bos_leads(id) ON DELETE CASCADE,
  deal_id UUID REFERENCES bos_deals(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES bos_contacts(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  public_url TEXT,
  size_bytes BIGINT,
  uploaded_by TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT bos_attachments_parent_chk CHECK (
    lead_id IS NOT NULL OR deal_id IS NOT NULL OR contact_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_bos_attachments_lead ON bos_attachments(lead_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bos_attachments_deal ON bos_attachments(deal_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bos_attachments_tenant ON bos_attachments(tenant_id) WHERE deleted_at IS NULL;

ALTER TABLE bos_attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bos_attachments_tenant_all ON bos_attachments;
CREATE POLICY bos_attachments_tenant_all ON bos_attachments FOR ALL TO authenticated
  USING (bos_tenant_ok(tenant_id))
  WITH CHECK (bos_tenant_ok(tenant_id));

-- Storage bucket for CRM files (public read optional; path is tenant-scoped)
INSERT INTO storage.buckets (id, name, public)
VALUES ('bos-attachments', 'bos-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS bos_attachments_storage_select ON storage.objects;
CREATE POLICY bos_attachments_storage_select ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'bos-attachments');

DROP POLICY IF EXISTS bos_attachments_storage_insert ON storage.objects;
CREATE POLICY bos_attachments_storage_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'bos-attachments');

DROP POLICY IF EXISTS bos_attachments_storage_delete ON storage.objects;
CREATE POLICY bos_attachments_storage_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'bos-attachments');

-- ── KB chunk embeddings (JSONB vector — OpenAI-compatible) ───────────────
ALTER TABLE bos_kb_chunks
  ADD COLUMN IF NOT EXISTS embedding JSONB;

COMMENT ON COLUMN bos_kb_chunks.embedding IS
  'Float array from OpenAI text-embedding-3-small (or similar); null if local-only';

-- ── Activities: assignee for tasks ───────────────────────────────────────
ALTER TABLE bos_activities
  ADD COLUMN IF NOT EXISTS assigned_to TEXT;

CREATE INDEX IF NOT EXISTS idx_bos_activities_due
  ON bos_activities (tenant_id, due_at)
  WHERE due_at IS NOT NULL AND completed_at IS NULL;

-- ── Merge leads RPC ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bos_merge_leads(p_keep_id uuid, p_merge_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid text := auth_firebase_uid();
  v_keep bos_leads%ROWTYPE;
  v_merge bos_leads%ROWTYPE;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  SELECT * INTO v_keep FROM bos_leads WHERE id = p_keep_id AND deleted_at IS NULL;
  SELECT * INTO v_merge FROM bos_leads WHERE id = p_merge_id AND deleted_at IS NULL;
  IF v_keep.id IS NULL OR v_merge.id IS NULL THEN
    RAISE EXCEPTION 'Lead not found';
  END IF;
  IF v_keep.tenant_id <> v_merge.tenant_id THEN
    RAISE EXCEPTION 'Cross-tenant merge blocked';
  END IF;
  IF NOT bos_is_member(v_keep.tenant_id) THEN
    RAISE EXCEPTION 'Not a member';
  END IF;
  IF p_keep_id = p_merge_id THEN
    RAISE EXCEPTION 'Cannot merge lead into itself';
  END IF;

  UPDATE bos_conversations SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_deals SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_activities SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_notes SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_voice_calls SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_attachments SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  UPDATE bos_campaign_recipients SET lead_id = p_keep_id WHERE lead_id = p_merge_id;
  DELETE FROM bos_lead_assignments WHERE lead_id = p_merge_id;

  UPDATE bos_leads SET
    full_name = COALESCE(NULLIF(v_keep.full_name, ''), v_merge.full_name),
    email = COALESCE(NULLIF(v_keep.email, ''), v_merge.email),
    phone = COALESCE(NULLIF(v_keep.phone, ''), v_merge.phone),
    company_name = COALESCE(NULLIF(v_keep.company_name, ''), v_merge.company_name),
    requirements = COALESCE(NULLIF(v_keep.requirements, ''), v_merge.requirements),
    ai_summary = COALESCE(v_keep.ai_summary, v_merge.ai_summary),
    score = CASE
      WHEN v_keep.score = 'hot' OR v_merge.score = 'hot' THEN 'hot'
      WHEN v_keep.score = 'warm' OR v_merge.score = 'warm' THEN 'warm'
      ELSE COALESCE(v_keep.score, v_merge.score)
    END,
    meta = COALESCE(v_keep.meta, '{}'::jsonb) || COALESCE(v_merge.meta, '{}'::jsonb)
      || jsonb_build_object('merged_from', p_merge_id),
    updated_at = now()
  WHERE id = p_keep_id;

  UPDATE bos_leads SET
    deleted_at = now(),
    stage = 'lost',
    meta = COALESCE(meta, '{}'::jsonb) || jsonb_build_object('merged_into', p_keep_id),
    updated_at = now()
  WHERE id = p_merge_id;

  INSERT INTO bos_audit_log (id, tenant_id, firebase_uid, action, entity_type, entity_id, meta)
  VALUES (
    gen_random_uuid(), v_keep.tenant_id, v_uid, 'lead.merge', 'bos_leads', p_keep_id,
    jsonb_build_object('merged_id', p_merge_id)
  );

  INSERT INTO bos_activities (id, tenant_id, activity_type, subject, body, lead_id, completed_at)
  VALUES (
    gen_random_uuid(), v_keep.tenant_id, 'lead.merge', 'Leads merged',
    'Merged lead ' || p_merge_id::text || ' into ' || p_keep_id::text,
    p_keep_id, now()
  );

  RETURN jsonb_build_object('ok', true, 'keep_id', p_keep_id, 'merged_id', p_merge_id);
END;
$$;

REVOKE ALL ON FUNCTION bos_merge_leads(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION bos_merge_leads(uuid, uuid) TO authenticated;

-- ── Plan limit helper ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bos_plan_limits(p_tenant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limits jsonb := '{}'::jsonb;
BEGIN
  SELECT COALESCE(p.limits, '{}'::jsonb) INTO v_limits
  FROM bos_tenants t
  LEFT JOIN bos_plans p ON p.id = t.plan_id
  WHERE t.id = p_tenant_id;
  RETURN COALESCE(v_limits, '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION bos_assert_lead_limit(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limits jsonb;
  v_max int;
  v_count int;
BEGIN
  v_limits := bos_plan_limits(p_tenant_id);
  v_max := COALESCE((v_limits->>'leads')::int, -1);
  IF v_max < 0 THEN RETURN; END IF;
  SELECT count(*)::int INTO v_count
  FROM bos_leads WHERE tenant_id = p_tenant_id AND deleted_at IS NULL;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Plan lead limit reached (%). Upgrade plan.', v_max;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION bos_assert_user_limit(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limits jsonb;
  v_max int;
  v_count int;
BEGIN
  v_limits := bos_plan_limits(p_tenant_id);
  v_max := COALESCE((v_limits->>'users')::int, -1);
  IF v_max < 0 THEN RETURN; END IF;
  SELECT count(*)::int INTO v_count
  FROM bos_tenant_members WHERE tenant_id = p_tenant_id AND deleted_at IS NULL AND is_active;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Plan user/seat limit reached (%). Upgrade plan.', v_max;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION bos_plan_limits(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION bos_assert_lead_limit(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION bos_assert_user_limit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION bos_plan_limits(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION bos_assert_lead_limit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION bos_assert_user_limit(uuid) TO authenticated;

-- Expand plan limits with AI quotas (display + Edge enforcement)
UPDATE bos_plans SET limits = COALESCE(limits, '{}'::jsonb) ||
  CASE code
    WHEN 'starter' THEN '{"ai_messages":2000,"voice_minutes":60,"api_calls":5000}'::jsonb
    WHEN 'growth' THEN '{"ai_messages":20000,"voice_minutes":600,"api_calls":50000}'::jsonb
    WHEN 'enterprise' THEN '{"ai_messages":-1,"voice_minutes":-1,"api_calls":-1}'::jsonb
    ELSE '{}'::jsonb
  END
WHERE code IN ('starter', 'growth', 'enterprise');

-- Settings write: prefer owner/admin (soft note — Flutter still gates; RLS remains member for MVP)
COMMENT ON TABLE bos_tenant_settings IS
  'Tenant settings + api_config/api_secrets. Mutations should be owner/admin (Flutter BosPermissions); Edge uses service role.';
