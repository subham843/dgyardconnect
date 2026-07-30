-- SEO blog posts for related content + internal linking on service landing pages

CREATE TABLE IF NOT EXISTS seo_blog_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  excerpt TEXT,
  body TEXT,
  hero_image_url TEXT,
  author_name TEXT NOT NULL DEFAULT 'D.G.Yard',
  city_slugs TEXT[] NOT NULL DEFAULT '{}',
  service_slugs TEXT[] NOT NULL DEFAULT '{}',
  seo_title TEXT,
  meta_description TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  published_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_seo_blog_posts_active ON seo_blog_posts (is_active, sort_order DESC, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_seo_blog_posts_city_slugs ON seo_blog_posts USING GIN (city_slugs);
CREATE INDEX IF NOT EXISTS idx_seo_blog_posts_service_slugs ON seo_blog_posts USING GIN (service_slugs);

DROP TRIGGER IF EXISTS seo_blog_posts_updated_at ON seo_blog_posts;
CREATE TRIGGER seo_blog_posts_updated_at
  BEFORE UPDATE ON seo_blog_posts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE VIEW v_public_seo_blog_posts AS
SELECT
  id, title, slug, excerpt, body, hero_image_url, author_name,
  city_slugs, service_slugs, seo_title, meta_description,
  sort_order, published_at, updated_at
FROM seo_blog_posts
WHERE is_active = true;

COMMENT ON VIEW v_public_seo_blog_posts IS
  'Public blog posts for /blog/{slug} and related links on SEO landing pages.';

ALTER TABLE seo_blog_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY seo_blog_posts_read ON seo_blog_posts
  FOR SELECT USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
CREATE POLICY seo_blog_posts_write ON seo_blog_posts
  FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());

GRANT SELECT ON v_public_seo_blog_posts TO anon, authenticated;

-- Seed: starter posts for Jharkhand services SEO
INSERT INTO seo_blog_posts (title, slug, excerpt, body, city_slugs, service_slugs, seo_title, meta_description, sort_order)
VALUES
  (
    'CCTV Installation Guide for Ranchi Homes and Offices',
    'cctv-installation-guide-ranchi',
    'Planning CCTV in Ranchi? Learn camera types, cable routes, NVR sizing, and compliance tips from D.G.Yard installers.',
    'Ranchi properties — from Piska More commercial strips to residential colonies — need surveillance matched to lighting, entry points, and storage retention. This guide covers HD vs IP cameras, PoE switching, and how we survey sites across Jharkhand before quoting.',
    ARRAY['ranchi'],
    ARRAY['cctv-installation'],
    'CCTV Installation Guide Ranchi | D.G.Yard',
    'Complete CCTV planning guide for Ranchi homes and offices — cameras, NVR, cabling, and site survey tips.',
    100
  ),
  (
    'Networking Checklist for Dhanbad Industrial Sites',
    'networking-checklist-dhanbad',
    'Structured cabling and switch planning for Dhanbad factories, schools, and offices.',
    'Industrial networking in Dhanbad demands labeled racks, surge-safe cabling, and VLAN separation between admin and production Wi-Fi. D.G.Yard documents every port and delivers as-built diagrams after handover.',
    ARRAY['dhanbad'],
    ARRAY['networking'],
    'Networking Checklist Dhanbad | D.G.Yard',
    'LAN and structured cabling checklist for Dhanbad industrial and commercial sites.',
    90
  ),
  (
    'Fire Alarm Compliance Basics in Jharkhand Commercial Buildings',
    'fire-alarm-compliance-jharkhand',
    'Smoke detectors, panels, and testing requirements for Jharkhand commercial projects.',
    'Fire alarm systems must be designed zone-by-zone with battery backup and audible coverage. We help Bokaro, Ranchi, and Jamshedpur clients select addressable panels and document testing for audits.',
    ARRAY['ranchi', 'bokaro', 'jamshedpur', 'dhanbad'],
    ARRAY['fire-alarm'],
    'Fire Alarm Compliance Jharkhand | D.G.Yard',
    'Fire detection and alarm compliance basics for commercial buildings in Jharkhand.',
    80
  ),
  (
    'Wi-Fi Site Survey Tips for Bokaro Campuses',
    'wifi-site-survey-bokaro',
    'How to eliminate dead zones in large Bokaro offices and housing societies.',
    'A proper RF survey maps interference, ceiling height, and user density before access point placement. D.G.Yard uses heatmap planning for Bokaro steel-city campuses and multi-block societies.',
    ARRAY['bokaro'],
    ARRAY['wifi-solutions'],
    'Wi-Fi Site Survey Bokaro | D.G.Yard',
    'Enterprise Wi-Fi planning and site survey tips for Bokaro offices and campuses.',
    70
  )
ON CONFLICT (slug) DO NOTHING;
