-- City × Service availability mapping
-- Controls which /{city}/{service} landing pages exist and navbar city flyouts.

CREATE TABLE IF NOT EXISTS seo_city_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id UUID NOT NULL REFERENCES seo_cities(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES seo_services(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (city_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_seo_city_services_service ON seo_city_services (service_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_seo_city_services_city ON seo_city_services (city_id, is_active, sort_order);

DROP TRIGGER IF EXISTS seo_city_services_updated_at ON seo_city_services;
CREATE TRIGGER seo_city_services_updated_at
  BEFORE UPDATE ON seo_city_services
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Backfill: all active cities × all active services (preserves current behaviour)
INSERT INTO seo_city_services (city_id, service_id, sort_order)
SELECT c.id, s.id, s.sort_order
FROM seo_cities c
CROSS JOIN seo_services s
WHERE c.is_active = true AND s.is_active = true
ON CONFLICT (city_id, service_id) DO NOTHING;

-- Public view: cities available per service
CREATE OR REPLACE VIEW v_public_seo_city_services AS
SELECT
  cs.id AS mapping_id,
  s.id AS service_id,
  s.slug AS service_slug,
  c.id AS city_id,
  c.name,
  c.state,
  c.slug,
  c.latitude,
  c.longitude,
  c.priority,
  c.description,
  c.service_available,
  c.nearby_districts,
  c.business_description,
  c.hero_image_url,
  c.image_url,
  c.faq,
  c.seo_title,
  c.meta_description,
  c.meta_keywords,
  c.og_title,
  c.og_description,
  c.canonical_url,
  c.robots,
  c.schema_override,
  c.updated_at,
  cs.sort_order
FROM seo_city_services cs
JOIN seo_services s ON s.id = cs.service_id AND s.is_active = true
JOIN seo_cities c ON c.id = cs.city_id AND c.is_active = true AND c.service_available = true
WHERE cs.is_active = true;

-- Sitemap: only mapped city × service URLs
CREATE OR REPLACE VIEW v_public_seo_landing_urls AS
SELECT
  c.slug AS city_slug,
  s.slug AS service_slug,
  GREATEST(c.updated_at, s.updated_at, cs.updated_at) AS updated_at
FROM seo_city_services cs
JOIN seo_cities c ON c.id = cs.city_id AND c.is_active = true AND c.service_available = true
JOIN seo_services s ON s.id = cs.service_id AND s.is_active = true
WHERE cs.is_active = true;

COMMENT ON VIEW v_public_seo_landing_urls IS
  'Indexable /{city_slug}/{service_slug} URLs where admin enabled city×service mapping.';

COMMENT ON TABLE seo_city_services IS
  'Which installation services are offered in which cities (navbar, hub, landing pages).';

-- RLS
ALTER TABLE seo_city_services ENABLE ROW LEVEL SECURITY;

CREATE POLICY seo_city_services_read ON seo_city_services
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY seo_city_services_write ON seo_city_services
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

GRANT SELECT ON v_public_seo_city_services TO anon, authenticated;
