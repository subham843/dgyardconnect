-- Phase B: public trial tenant bootstrap + onboarding helpers

CREATE OR REPLACE FUNCTION bos_slugify(p_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT trim(both '-' FROM regexp_replace(lower(coalesce(p_text, '')), '[^a-z0-9]+', '-', 'g'));
$$;

CREATE OR REPLACE FUNCTION bos_bootstrap_tenant(
  p_company_name text,
  p_slug text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_display_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid text := auth_firebase_uid();
  v_name text := trim(p_company_name);
  v_slug text;
  v_base text;
  v_tenant_id uuid;
  v_member_id uuid;
  v_plan_id uuid := 'a0000000-0000-4000-8000-000000000001'; -- starter
  v_n int := 0;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_name IS NULL OR length(v_name) < 2 THEN
    RAISE EXCEPTION 'Company name required';
  END IF;

  -- One owned tenant per user (owner role) for MVP
  IF EXISTS (
    SELECT 1 FROM bos_tenant_members m
    WHERE m.firebase_uid = v_uid
      AND m.role = 'owner'
      AND m.deleted_at IS NULL
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'You already own a tenant';
  END IF;

  v_base := bos_slugify(COALESCE(NULLIF(trim(p_slug), ''), v_name));
  IF v_base IS NULL OR v_base = '' THEN
    v_base := 'company';
  END IF;
  v_slug := v_base;
  WHILE EXISTS (SELECT 1 FROM bos_tenants WHERE slug = v_slug AND deleted_at IS NULL) LOOP
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n::text;
  END LOOP;

  v_tenant_id := gen_random_uuid();
  v_member_id := gen_random_uuid();

  INSERT INTO bos_tenants (
    id, name, slug, status, plan_id, brand_primary, brand_accent, settings
  ) VALUES (
    v_tenant_id,
    v_name,
    v_slug,
    'trial',
    v_plan_id,
    '#0F172A',
    '#2563EB',
    jsonb_build_object(
      'onboarding_completed', false,
      'onboarding_step', 0,
      'catalog_seed', 'empty'
    )
  );

  INSERT INTO bos_tenant_members (
    id, tenant_id, firebase_uid, role, email, display_name, is_active
  ) VALUES (
    v_member_id,
    v_tenant_id,
    v_uid,
    'owner',
    CASE WHEN p_email IS NULL OR trim(p_email) = '' THEN NULL ELSE lower(trim(p_email)) END,
    NULLIF(trim(COALESCE(p_display_name, '')), ''),
    true
  );

  INSERT INTO bos_subscriptions (
    tenant_id, plan_id, status, current_period_start, current_period_end
  ) VALUES (
    v_tenant_id,
    v_plan_id,
    'trialing',
    now(),
    now() + interval '14 days'
  );

  INSERT INTO bos_tenant_settings (tenant_id, settings)
  VALUES (
    v_tenant_id,
    jsonb_build_object(
      'timezone', 'Asia/Kolkata',
      'currency', 'INR',
      'onboarding_completed', false
    )
  )
  ON CONFLICT (tenant_id) DO NOTHING;

  INSERT INTO bos_pipeline_stages (tenant_id, code, label, sort_order, is_won, is_lost)
  VALUES
    (v_tenant_id, 'qualification', 'Qualification', 1, false, false),
    (v_tenant_id, 'discovery', 'Discovery', 2, false, false),
    (v_tenant_id, 'proposal', 'Proposal', 3, false, false),
    (v_tenant_id, 'negotiation', 'Negotiation', 4, false, false),
    (v_tenant_id, 'won', 'Won', 5, true, false),
    (v_tenant_id, 'lost', 'Lost', 6, false, true)
  ON CONFLICT (tenant_id, code) DO NOTHING;

  INSERT INTO bos_departments (tenant_id, name, code)
  VALUES
    (v_tenant_id, 'Sales', 'sales'),
    (v_tenant_id, 'Support', 'support'),
    (v_tenant_id, 'Operations', 'operations');

  INSERT INTO bos_audit_log (id, tenant_id, firebase_uid, action, entity_type, entity_id, meta)
  VALUES (
    gen_random_uuid(),
    v_tenant_id,
    v_uid,
    'tenant.bootstrap',
    'bos_tenants',
    v_tenant_id,
    jsonb_build_object('slug', v_slug, 'plan', 'starter')
  );

  RETURN jsonb_build_object(
    'tenant_id', v_tenant_id,
    'member_id', v_member_id,
    'slug', v_slug,
    'plan_id', v_plan_id,
    'status', 'trial'
  );
END;
$$;

REVOKE ALL ON FUNCTION bos_bootstrap_tenant(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION bos_bootstrap_tenant(text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION bos_complete_onboarding(p_catalog_seed text DEFAULT 'empty')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid text := auth_firebase_uid();
  v_tid uuid := bos_auth_tenant_id();
  v_seed text := coalesce(nullif(trim(p_catalog_seed), ''), 'empty');
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF v_tid IS NULL THEN
    RAISE EXCEPTION 'No active tenant in JWT';
  END IF;
  IF NOT bos_is_member(v_tid) THEN
    RAISE EXCEPTION 'Not a tenant member';
  END IF;
  IF bos_auth_member_role() NOT IN ('owner', 'admin') AND NOT auth_is_superadmin() THEN
    RAISE EXCEPTION 'Only owner/admin can complete onboarding';
  END IF;
  IF v_seed NOT IN ('empty', 'csv', 'marketplace') THEN
    v_seed := 'empty';
  END IF;

  UPDATE bos_tenants SET
    settings = coalesce(settings, '{}'::jsonb)
      || jsonb_build_object(
        'onboarding_completed', true,
        'onboarding_step', 99,
        'catalog_seed', v_seed
      ),
    updated_at = now()
  WHERE id = v_tid;

  INSERT INTO bos_tenant_settings (tenant_id, settings)
  VALUES (
    v_tid,
    jsonb_build_object(
      'timezone', 'Asia/Kolkata',
      'currency', 'INR',
      'onboarding_completed', true,
      'catalog_seed', v_seed
    )
  )
  ON CONFLICT (tenant_id) DO UPDATE SET
    settings = coalesce(bos_tenant_settings.settings, '{}'::jsonb)
      || jsonb_build_object(
        'onboarding_completed', true,
        'catalog_seed', v_seed
      ),
    updated_at = now();

  INSERT INTO bos_audit_log (id, tenant_id, firebase_uid, action, entity_type, entity_id, meta)
  VALUES (
    gen_random_uuid(),
    v_tid,
    v_uid,
    'tenant.onboarding_complete',
    'bos_tenants',
    v_tid,
    jsonb_build_object('catalog_seed', v_seed)
  );

  RETURN jsonb_build_object('tenant_id', v_tid, 'onboarding_completed', true, 'catalog_seed', v_seed);
END;
$$;

REVOKE ALL ON FUNCTION bos_complete_onboarding(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION bos_complete_onboarding(text) TO authenticated;
