-- Dynamic SEO Services Engine — cities × services landing pages
-- URLs: /{city_slug}/{service_slug}  e.g. /ranchi/cctv-installation

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS seo_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  short_description TEXT,
  description TEXT,
  hero_image_url TEXT,
  icon_name TEXT DEFAULT 'build_rounded',
  features JSONB NOT NULL DEFAULT '[]'::jsonb,
  process_steps JSONB NOT NULL DEFAULT '[]'::jsonb,
  why_choose JSONB NOT NULL DEFAULT '[]'::jsonb,
  areas_covered_template TEXT,
  pricing_cta_text TEXT DEFAULT 'Get a free quote',
  related_product_category_slugs TEXT[] NOT NULL DEFAULT '{}',
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  -- SEO template overrides (optional; auto-generated when null)
  seo_title_template TEXT,
  meta_description_template TEXT,
  h1_template TEXT,
  h2_features_template TEXT,
  faq_template JSONB NOT NULL DEFAULT '[]'::jsonb,
  schema_service_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seo_cities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  state TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  priority INT NOT NULL DEFAULT 0,
  description TEXT,
  service_available BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  nearby_districts TEXT[] NOT NULL DEFAULT '{}',
  business_description TEXT,
  hero_image_url TEXT,
  image_url TEXT,
  faq JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- SEO overrides (optional; auto-generated when null)
  seo_title TEXT,
  meta_description TEXT,
  meta_keywords TEXT,
  og_title TEXT,
  og_description TEXT,
  canonical_url TEXT,
  robots TEXT DEFAULT 'index, follow',
  schema_override JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS seo_city_nearby (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_id UUID NOT NULL REFERENCES seo_cities(id) ON DELETE CASCADE,
  nearby_city_id UUID NOT NULL REFERENCES seo_cities(id) ON DELETE CASCADE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (city_id, nearby_city_id),
  CHECK (city_id <> nearby_city_id)
);

CREATE INDEX IF NOT EXISTS idx_seo_services_active_order ON seo_services (is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_seo_cities_active_priority ON seo_cities (is_active, priority DESC, name);
CREATE INDEX IF NOT EXISTS idx_seo_city_nearby_city ON seo_city_nearby (city_id, sort_order);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS seo_services_updated_at ON seo_services;
CREATE TRIGGER seo_services_updated_at
  BEFORE UPDATE ON seo_services
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS seo_cities_updated_at ON seo_cities;
CREATE TRIGGER seo_cities_updated_at
  BEFORE UPDATE ON seo_cities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- PUBLIC VIEWS (anonymous read)
-- ============================================================================

CREATE OR REPLACE VIEW v_public_seo_services AS
SELECT
  id, name, slug, short_description, description,
  hero_image_url, icon_name, features, process_steps, why_choose,
  areas_covered_template, pricing_cta_text, related_product_category_slugs,
  sort_order, seo_title_template, meta_description_template,
  h1_template, h2_features_template, faq_template, schema_service_type,
  updated_at
FROM seo_services
WHERE is_active = true;

CREATE OR REPLACE VIEW v_public_seo_cities AS
SELECT
  id, name, state, slug, latitude, longitude, priority,
  description, service_available, nearby_districts, business_description,
  hero_image_url, image_url, faq,
  seo_title, meta_description, meta_keywords,
  og_title, og_description, canonical_url, robots, schema_override,
  updated_at
FROM seo_cities
WHERE is_active = true AND service_available = true;

CREATE OR REPLACE VIEW v_public_seo_city_nearby AS
SELECT
  n.city_id,
  c.slug AS city_slug,
  nc.id AS nearby_city_id,
  nc.name AS nearby_city_name,
  nc.state AS nearby_city_state,
  nc.slug AS nearby_city_slug,
  n.sort_order
FROM seo_city_nearby n
JOIN seo_cities c ON c.id = n.city_id AND c.is_active = true AND c.service_available = true
JOIN seo_cities nc ON nc.id = n.nearby_city_id AND nc.is_active = true AND nc.service_available = true;

-- Cross join for sitemap generation (active city × active service)
CREATE OR REPLACE VIEW v_public_seo_landing_urls AS
SELECT
  c.slug AS city_slug,
  s.slug AS service_slug,
  GREATEST(c.updated_at, s.updated_at) AS updated_at
FROM seo_cities c
CROSS JOIN seo_services s
WHERE c.is_active = true
  AND c.service_available = true
  AND s.is_active = true;

COMMENT ON VIEW v_public_seo_landing_urls IS
  'All indexable /{city_slug}/{service_slug} URLs for sitemap generation.';

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE seo_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE seo_city_nearby ENABLE ROW LEVEL SECURITY;

CREATE POLICY seo_services_read ON seo_services
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY seo_services_write ON seo_services
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY seo_cities_read ON seo_cities
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY seo_cities_write ON seo_cities
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

CREATE POLICY seo_city_nearby_read ON seo_city_nearby
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY seo_city_nearby_write ON seo_city_nearby
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

-- Anonymous read via views (same pattern as shop public views)
GRANT SELECT ON v_public_seo_services TO anon, authenticated;
GRANT SELECT ON v_public_seo_cities TO anon, authenticated;
GRANT SELECT ON v_public_seo_city_nearby TO anon, authenticated;
GRANT SELECT ON v_public_seo_landing_urls TO anon, authenticated;

-- ============================================================================
-- SEED: 10 installation services
-- ============================================================================

INSERT INTO seo_services (name, slug, short_description, description, icon_name, features, process_steps, why_choose, sort_order, schema_service_type, faq_template)
VALUES
  ('CCTV Installation', 'cctv-installation',
   'Professional CCTV camera installation for homes, offices, and industries.',
   'End-to-end CCTV surveillance — site survey, camera placement, NVR/DVR setup, remote viewing, and AMC support.',
   'videocam_rounded',
   '["HD & IP camera installation","NVR/DVR configuration","Remote mobile viewing","Night vision & PTZ cameras","Warranty-backed workmanship"]'::jsonb,
   '[{"title":"Site survey","description":"We assess lighting, coverage zones, and cable routes."},{"title":"BOQ & quotation","description":"Transparent pricing with branded equipment options."},{"title":"Installation","description":"Clean cabling, camera mounting, and NVR setup."},{"title":"Handover & training","description":"Live demo, mobile app setup, and documentation."}]'::jsonb,
   '["Certified technicians","Pan-India scalable delivery","Branded CCTV products","Fast post-install support"]'::jsonb,
   10, 'CCTVInstallationService',
   '[{"q":"How much does CCTV installation cost in {{city}}?","a":"Pricing depends on camera count, cable length, and NVR capacity. We provide a free site survey and itemized BOQ for {{city}} properties."},{"q":"Do you offer AMC for CCTV in {{city}}?","a":"Yes — annual maintenance contracts with scheduled health checks and priority technician visits across {{city}} and {{state}}."}]'::jsonb),

  ('Biometric Installation', 'biometric-installation',
   'Biometric attendance and access devices installed by certified technicians.',
   'Fingerprint, face recognition, and card-based biometric systems for offices, factories, and institutions.',
   'fingerprint_rounded',
   '["Fingerprint & face devices","HR software integration","Multi-location sync","Visitor management","AMC & calibration"]'::jsonb,
   '[{"title":"Requirement analysis","description":"User count, shift patterns, and integration needs."},{"title":"Device selection","description":"Right biometric model for your site in {{city}}."},{"title":"Installation & wiring","description":"Mounting, LAN/power, and software configuration."},{"title":"User enrollment","description":"Staff registration and reporting setup."}]'::jsonb,
   '["Enterprise-grade brands","Clean cable management","On-site training","Reliable after-sales"]'::jsonb,
   20, 'BiometricInstallationService',
   '[{"q":"Which biometric brands do you install in {{city}}?","a":"We deploy leading Indian and global brands suited to {{city}} climate and site requirements."}]'::jsonb),

  ('Networking', 'networking',
   'Structured LAN cabling, switches, racks, and office network design.',
   'Complete networking for offices and campuses — CAT6/CAT6A cabling, patch panels, switches, VLANs, and documentation.',
   'dns_rounded',
   '["Structured cabling","Switch & router setup","Server rack dressing","VLAN & Wi-Fi planning","Network documentation"]'::jsonb,
   '[{"title":"Network design","description":"Floor plans, port counts, and backbone planning for {{city}} sites."},{"title":"Cabling execution","description":"Conduit, trays, labeling, and testing."},{"title":"Active equipment","description":"Switch configuration and firewall basics."},{"title":"Testing & handover","description":"Certification reports and as-built diagrams."}]'::jsonb,
   '["TIA/EIA standards","Labeled clean racks","Scalable design","BOQ transparency"]'::jsonb,
   30, 'NetworkingService',
   '[{"q":"Do you provide networking for new offices in {{city}}?","a":"Yes — greenfield and retrofit LAN projects across {{city}}, {{state}}, with full BOQ and execution."}]'::jsonb),

  ('Fire Alarm', 'fire-alarm',
   'Fire detection and alarm systems for commercial and residential buildings.',
   'Conventional and addressable fire alarm panels, smoke detectors, hooters, and compliance-ready installation.',
   'local_fire_department_rounded',
   '["Smoke & heat detectors","Addressable panels","Hooters & strobes","Fire NOC support","Periodic testing"]'::jsonb,
   '[{"title":"Risk assessment","description":"Zone mapping per floor and occupancy in {{city}}."},{"title":"System design","description":"Panel capacity, detector types, and battery backup."},{"title":"Installation","description":"Detector mounting, loop wiring, and panel programming."},{"title":"Testing & certification","description":"Functional tests and handover documents."}]'::jsonb,
   '["Code-aware design","Quality detectors","Documented testing","Maintenance plans"]'::jsonb,
   40, 'FireAlarmInstallationService',
   '[{"q":"Is fire alarm installation mandatory in {{city}} commercial buildings?","a":"Most commercial and high-rise projects require approved fire safety systems. We help {{city}} clients meet local compliance."}]'::jsonb),

  ('Access Control', 'access-control',
   'Door access control — cards, biometrics, electromagnetic locks, and controllers.',
   'Secure entry management for offices, societies, and industrial gates with audit trails.',
   'lock_rounded',
   '["Card & biometric readers","EM locks & strikes","Multi-door controllers","Visitor logs","Integration with CCTV"]'::jsonb,
   '[{"title":"Access audit","description":"Doors, user groups, and schedules for {{city}} facilities."},{"title":"Hardware install","description":"Readers, locks, power supplies, and controllers."},{"title":"Software config","description":"User roles, time zones, and reporting."},{"title":"Training","description":"Admin training and emergency override procedures."}]'::jsonb,
   '["Reliable hardware","Audit-ready logs","Scalable controllers","Professional cabling"]'::jsonb,
   50, 'AccessControlInstallationService',
   '[]'::jsonb),

  ('EPABX', 'epabx',
   'EPABX and IP-PBX telephone systems for businesses.',
   'Analog and IP telephony — extensions, IVR, call routing, and office intercom solutions.',
   'phone_in_talk_rounded',
   '["IP & analog EPABX","Extension wiring","IVR & call routing","Intercom integration","AMC support"]'::jsonb,
   '[{"title":"Capacity planning","description":"Extension count and trunk lines for {{city}} offices."},{"title":"Cabling","description":"Internal telephone cabling and patch panels."},{"title":"PBX setup","description":"Programming, IVR, and outbound rules."},{"title":"User training","description":"Handover and documentation."}]'::jsonb,
   '["Leading PBX brands","Clean telecom racks","Remote support","Upgrade paths"]'::jsonb,
   60, 'TelephoneSystemInstallationService',
   '[]'::jsonb),

  ('Fiber Installation', 'fiber-installation',
   'Optical fiber laying, splicing, OTDR testing, and backbone links.',
   'Single-mode and multi-mode fiber for campuses, towers, and long-distance links in {{city}} region.',
   'cable_rounded',
   '["Fiber laying & splicing","OTDR testing","LIU & patch panels","Backbone links","Fault repair"]'::jsonb,
   '[{"title":"Route survey","description":"Trench, duct, or aerial path planning."},{"title":"Cable laying","description":"Professional pulling and protection."},{"title":"Splicing & termination","description":"Fusion splicing and LIU patching."},{"title":"Testing","description":"OTDR reports and loss budgets."}]'::jsonb,
   '["Certified splicers","Test reports","Durable enclosures","Rapid fault response"]'::jsonb,
   70, 'FiberOpticInstallationService',
   '[]'::jsonb),

  ('WiFi Solutions', 'wifi-solutions',
   'Enterprise and home Wi-Fi — access points, mesh, and heatmap coverage.',
   'High-density Wi-Fi design for offices, hotels, warehouses, and residential complexes.',
   'wifi_rounded',
   '["Site survey & heatmap","Access point install","Mesh & controller setup","Guest portals","Performance tuning"]'::jsonb,
   '[{"title":"RF survey","description":"Coverage mapping for {{city}} buildings."},{"title":"AP placement","description":"Ceiling/wall mount with PoE cabling."},{"title":"Controller config","description":"SSID, VLAN, and security policies."},{"title":"Optimization","description":"Channel planning and handover testing."}]'::jsonb,
   '["Enterprise AP brands","Dead-zone elimination","Secure guest Wi-Fi","Scalable controllers"]'::jsonb,
   80, 'WiFiInstallationService',
   '[]'::jsonb),

  ('Computer Installation', 'computer-installation',
   'Desktop, laptop setup, OS imaging, and workstation deployment.',
   'Bulk PC rollout for offices — imaging, software stack, domain join, and desk-side support.',
   'computer_rounded',
   '["OS installation & imaging","Software deployment","Domain & network join","Peripheral setup","Asset tagging"]'::jsonb,
   '[{"title":"Inventory & imaging","description":"Standard build for {{city}} office rollouts."},{"title":"Desk deployment","description":"Install, cable management, and testing."},{"title":"Software stack","description":"Office apps, antivirus, and policies."},{"title":"Handover","description":"User checklist and support contact."}]'::jsonb,
   '["Fast bulk rollout","Standardized builds","Minimal downtime","On-site support"]'::jsonb,
   90, 'ComputerSetupService',
   '[]'::jsonb),

  ('Server Installation', 'server-installation',
   'Server rack mounting, RAID, hypervisor, and backup setup.',
   'On-prem and hybrid server deployment — hardware install, virtualization, and monitoring.',
   'storage_rounded',
   '["Rack & power setup","RAID & storage config","Hypervisor install","Backup policies","Remote monitoring"]'::jsonb,
   '[{"title":"Infrastructure review","description":"Rack space, power, and cooling in {{city}} DC/MDF."},{"title":"Hardware install","description":"Rail kit, cabling, and labeling."},{"title":"OS & hypervisor","description":"Windows/Linux or VMware/Hyper-V setup."},{"title":"Backup & monitoring","description":"Snapshot policies and alert configuration."}]'::jsonb,
   '["Data-center discipline","Documented configs","High availability options","24×7 monitoring add-ons"]'::jsonb,
   100, 'ServerInstallationService',
   '[]'::jsonb)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- SEED: launch cities (Jharkhand)
-- ============================================================================

INSERT INTO seo_cities (name, state, slug, latitude, longitude, priority, description, business_description, nearby_districts)
VALUES
  ('Ranchi', 'Jharkhand', 'ranchi', 23.3441, 85.3096, 100,
   'Jharkhand capital and primary service hub for CCTV, networking, and IT installation.',
   'D.G.Yard delivers end-to-end security and IT projects across Ranchi — from Piska More headquarters to commercial hubs and residential societies.',
   ARRAY['Khunti', 'Ramgarh', 'Lohardaga']),
  ('Dhanbad', 'Jharkhand', 'dhanbad', 23.7957, 86.4304, 90,
   'Coal belt industrial city with strong demand for security, networking, and fire safety systems.',
   'We serve Dhanbad industries, schools, and housing projects with certified installation teams and transparent BOQ.',
   ARRAY['Bokaro', 'Giridih', 'Jamtara']),
  ('Bokaro', 'Jharkhand', 'bokaro', 23.6693, 86.1511, 85,
   'Steel city with large industrial and residential campuses needing integrated security and IT.',
   'D.G.Yard Bokaro team handles CCTV, access control, and plant networking with compliance-ready documentation.',
   ARRAY['Dhanbad', 'Ramgarh', 'Purulia']),
  ('Jamshedpur', 'Jharkhand', 'jamshedpur', 22.8046, 86.2029, 80,
   'Tata Steel hub — corporate campuses, factories, and premium housing.',
   'From Tata Nagar industrial sites to Sakchi retail, we deploy scalable security and networking in Jamshedpur.',
   ARRAY['East Singhbhum', 'Seraikela', 'Ghatshila'])
ON CONFLICT (slug) DO NOTHING;

-- Nearby city linking: Ranchi → Bokaro → Dhanbad → Jamshedpur
INSERT INTO seo_city_nearby (city_id, nearby_city_id, sort_order)
SELECT c.id, nc.id, v.ord
FROM (VALUES
  ('ranchi', 'bokaro', 1),
  ('ranchi', 'dhanbad', 2),
  ('ranchi', 'jamshedpur', 3),
  ('bokaro', 'dhanbad', 1),
  ('bokaro', 'ranchi', 2),
  ('bokaro', 'jamshedpur', 3),
  ('dhanbad', 'bokaro', 1),
  ('dhanbad', 'ranchi', 2),
  ('dhanbad', 'jamshedpur', 3),
  ('jamshedpur', 'dhanbad', 1),
  ('jamshedpur', 'bokaro', 2),
  ('jamshedpur', 'ranchi', 3)
) AS v(city_slug, nearby_slug, ord)
JOIN seo_cities c ON c.slug = v.city_slug
JOIN seo_cities nc ON nc.slug = v.nearby_slug
ON CONFLICT (city_id, nearby_city_id) DO NOTHING;
