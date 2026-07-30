-- Phase A: departments + member department_id + tenant invites + accept RPC

CREATE TABLE IF NOT EXISTS bos_departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_bos_departments_tenant_name
  ON bos_departments (tenant_id, lower(name))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_bos_departments_tenant
  ON bos_departments (tenant_id)
  WHERE deleted_at IS NULL;

ALTER TABLE bos_tenant_members
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES bos_departments(id);

CREATE TABLE IF NOT EXISTS bos_tenant_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES bos_tenants(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role bos_member_role NOT NULL DEFAULT 'viewer',
  department_id UUID REFERENCES bos_departments(id),
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked', 'expired')),
  invited_by_uid TEXT,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '14 days'),
  accepted_at TIMESTAMPTZ,
  accepted_firebase_uid TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bos_tenant_invites_tenant
  ON bos_tenant_invites (tenant_id, status);

CREATE INDEX IF NOT EXISTS idx_bos_tenant_invites_email
  ON bos_tenant_invites (tenant_id, lower(email));

-- Seed departments for DG.YARD
INSERT INTO bos_departments (id, tenant_id, name, code)
VALUES
  ('d0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Sales', 'sales'),
  ('d0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Support', 'support'),
  ('d0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'Operations', 'operations')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE bos_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bos_tenant_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bos_departments_select ON bos_departments;
CREATE POLICY bos_departments_select ON bos_departments FOR SELECT TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id));
DROP POLICY IF EXISTS bos_departments_write ON bos_departments;
CREATE POLICY bos_departments_write ON bos_departments FOR ALL TO authenticated
  USING (
    auth_is_superadmin()
    OR (
      bos_is_member(tenant_id)
      AND bos_auth_member_role() IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    auth_is_superadmin()
    OR (
      bos_is_member(tenant_id)
      AND bos_auth_member_role() IN ('owner', 'admin')
    )
  );

DROP POLICY IF EXISTS bos_tenant_invites_select ON bos_tenant_invites;
CREATE POLICY bos_tenant_invites_select ON bos_tenant_invites FOR SELECT TO authenticated
  USING (auth_is_superadmin() OR bos_is_member(tenant_id));
DROP POLICY IF EXISTS bos_tenant_invites_write ON bos_tenant_invites;
CREATE POLICY bos_tenant_invites_write ON bos_tenant_invites FOR ALL TO authenticated
  USING (
    auth_is_superadmin()
    OR (
      bos_is_member(tenant_id)
      AND bos_auth_member_role() IN ('owner', 'admin')
    )
  )
  WITH CHECK (
    auth_is_superadmin()
    OR (
      bos_is_member(tenant_id)
      AND bos_auth_member_role() IN ('owner', 'admin')
    )
  );

-- Accept invite as any authenticated Firebase user (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION bos_accept_invite(p_token text, p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid text := auth_firebase_uid();
  v_invite bos_tenant_invites%ROWTYPE;
  v_member_id uuid;
BEGIN
  IF v_uid IS NULL OR v_uid = '' THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
    RAISE EXCEPTION 'Invite token required';
  END IF;
  IF p_email IS NULL OR length(trim(p_email)) = 0 THEN
    RAISE EXCEPTION 'Email required';
  END IF;

  SELECT * INTO v_invite
  FROM bos_tenant_invites
  WHERE token = trim(p_token)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite not found';
  END IF;
  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'Invite is not pending';
  END IF;
  IF v_invite.expires_at < now() THEN
    UPDATE bos_tenant_invites SET status = 'expired', updated_at = now() WHERE id = v_invite.id;
    RAISE EXCEPTION 'Invite expired';
  END IF;
  IF lower(trim(v_invite.email)) <> lower(trim(p_email)) THEN
    RAISE EXCEPTION 'Email does not match invite';
  END IF;

  SELECT id INTO v_member_id
  FROM bos_tenant_members
  WHERE tenant_id = v_invite.tenant_id
    AND firebase_uid = v_uid
    AND deleted_at IS NULL
  LIMIT 1;

  IF v_member_id IS NULL THEN
    v_member_id := gen_random_uuid();
    INSERT INTO bos_tenant_members (
      id, tenant_id, firebase_uid, role, email, department_id, is_active
    ) VALUES (
      v_member_id,
      v_invite.tenant_id,
      v_uid,
      v_invite.role,
      lower(trim(p_email)),
      v_invite.department_id,
      true
    );
  ELSE
    UPDATE bos_tenant_members SET
      role = v_invite.role,
      email = lower(trim(p_email)),
      department_id = COALESCE(v_invite.department_id, department_id),
      is_active = true,
      deleted_at = NULL
    WHERE id = v_member_id;
  END IF;

  UPDATE bos_tenant_invites SET
    status = 'accepted',
    accepted_at = now(),
    accepted_firebase_uid = v_uid,
    updated_at = now()
  WHERE id = v_invite.id;

  INSERT INTO bos_audit_log (id, tenant_id, firebase_uid, action, entity_type, entity_id, meta)
  VALUES (
    gen_random_uuid(),
    v_invite.tenant_id,
    v_uid,
    'invite.accept',
    'bos_tenant_invites',
    v_invite.id,
    jsonb_build_object('member_id', v_member_id)
  );

  RETURN v_member_id;
END;
$$;

REVOKE ALL ON FUNCTION bos_accept_invite(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION bos_accept_invite(text, text) TO authenticated;
