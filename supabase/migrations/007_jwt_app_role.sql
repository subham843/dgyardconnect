-- PostgREST uses JWT "role" as the Postgres role (authenticated/anon). App roles live in app_role.

CREATE OR REPLACE FUNCTION auth_is_superadmin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    auth.jwt() ->> 'app_role',
    auth.jwt() -> 'user_metadata' ->> 'app_role',
    ''
  ) = 'superadmin';
$$ LANGUAGE sql STABLE;
