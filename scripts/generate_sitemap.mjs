#!/usr/bin/env node
/**
 * Generates web/sitemap.xml from static public routes + Supabase catalog data.
 * Run: node scripts/generate_sitemap.mjs
 */
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

const SITE = process.env.SITE_SEO_BASE_URL || 'https://dgyard.com';
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://xtnfmrourhzspehvhrkz.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY || 'sb_publishable_a4RQmOWKCKXJNIBnyaquDw_l46BoO5B';

const STATIC_ROUTES = [
  { path: '/', changefreq: 'weekly', priority: '1.0' },
  { path: '/store', changefreq: 'daily', priority: '0.9' },
  { path: '/calculator', changefreq: 'weekly', priority: '0.8' },
  { path: '/services', changefreq: 'weekly', priority: '0.85' },
  { path: '/services/cities', changefreq: 'weekly', priority: '0.75' },
  { path: '/connect', changefreq: 'monthly', priority: '0.8' },
  { path: '/about', changefreq: 'monthly', priority: '0.7' },
  { path: '/contact', changefreq: 'monthly', priority: '0.7' },
  { path: '/support', changefreq: 'monthly', priority: '0.6' },
  { path: '/privacy-policy', changefreq: 'yearly', priority: '0.4' },
  { path: '/data-deletion', changefreq: 'yearly', priority: '0.3' },
];

async function fetchAll(table, select, order) {
  const rows = [];
  const pageSize = 1000;
  let offset = 0;
  for (;;) {
    const url = new URL(`/rest/v1/${table}`, SUPABASE_URL);
    url.searchParams.set('select', select);
    if (order) url.searchParams.set('order', order);
    url.searchParams.set('limit', String(pageSize));
    url.searchParams.set('offset', String(offset));

    const res = await fetch(url, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      },
    });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`Supabase ${table} ${res.status}: ${body}`);
    }
    const batch = await res.json();
    if (!Array.isArray(batch) || batch.length === 0) break;
    rows.push(...batch);
    if (batch.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

function esc(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function entry(path, changefreq, priority, lastmod) {
  const loc = `${SITE}${path.startsWith('/') ? path : `/${path}`}`;
  const last = lastmod ? `<lastmod>${esc(lastmod)}</lastmod>` : '';
  return `  <url><loc>${esc(loc)}</loc>${last}<changefreq>${changefreq}</changefreq><priority>${priority}</priority></url>`;
}

async function main() {
  const urls = [...STATIC_ROUTES];

  const categories = await fetchAll('v_public_categories', 'slug,updated_at', 'sort_order');
  for (const row of categories) {
    const slug = (row.slug || '').trim();
    if (!slug) continue;
    urls.push({
      path: `/store/category/${slug}`,
      changefreq: 'weekly',
      priority: '0.75',
      lastmod: row.updated_at?.slice(0, 10),
    });
  }

  const products = await fetchAll('v_public_products', 'url_slug,updated_at', 'name');
  for (const row of products) {
    const slug = (row.url_slug || '').trim();
    if (!slug) continue;
    urls.push({
      path: `/product/${slug}`,
      changefreq: 'weekly',
      priority: '0.7',
      lastmod: row.updated_at?.slice(0, 10),
    });
  }

  let calculators = [];
  try {
    calculators = await fetchAll('v_public_calculator_families', 'slug,updated_at', 'sort_order');
  } catch (e) {
    console.warn('Calculator families skipped:', e.message);
  }
  for (const row of calculators) {
    const slug = (row.slug || '').trim();
    if (!slug) continue;
    urls.push({
      path: `/calculator/${slug}`,
      changefreq: 'monthly',
      priority: '0.65',
      lastmod: row.updated_at?.slice(0, 10),
    });
  }

  let seoLandings = [];
  try {
    seoLandings = await fetchAll('v_public_seo_landing_urls', 'city_slug,service_slug,updated_at', 'city_slug');
  } catch (e) {
    console.warn('SEO landing URLs skipped:', e.message);
  }
  for (const row of seoLandings) {
    const city = (row.city_slug || '').trim();
    const service = (row.service_slug || '').trim();
    if (!city || !service) continue;
    urls.push({
      path: `/${city}/${service}`,
      changefreq: 'weekly',
      priority: '0.7',
      lastmod: row.updated_at?.slice(0, 10),
    });
  }

  let blogs = [];
  try {
    blogs = await fetchAll('v_public_seo_blog_posts', 'slug,updated_at', 'sort_order');
  } catch (e) {
    console.warn('SEO blog posts skipped:', e.message);
  }
  for (const row of blogs) {
    const slug = (row.slug || '').trim();
    if (!slug) continue;
    urls.push({
      path: `/blog/${slug}`,
      changefreq: 'monthly',
      priority: '0.65',
      lastmod: row.updated_at?.slice(0, 10),
    });
  }

  const seen = new Set();
  const unique = [];
  for (const u of urls) {
    if (seen.has(u.path)) continue;
    seen.add(u.path);
    unique.push(u);
  }

  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...unique.map((u) => entry(u.path, u.changefreq, u.priority, u.lastmod)),
    '</urlset>',
    '',
  ].join('\n');

  // Sanity checks — fail fast if old domain or private routes slip in.
  const blocked = ['/login', '/admin', '/dealer', '/technician', '/shop', '/marketplace'];
  for (const u of unique) {
    if (blocked.some((p) => u.path === p || u.path.startsWith(`${p}/`))) {
      throw new Error(`Refusing to write sitemap: private route ${u.path}`);
    }
  }
  if (xml.includes('dgyard-connect.web.app') || xml.includes('firebaseapp.com')) {
    throw new Error(`Refusing to write sitemap: wrong host in output (expected ${SITE})`);
  }

  const targets = [join(root, 'web', 'sitemap.xml')];
  const buildOut = join(root, 'build', 'web', 'sitemap.xml');
  if (process.env.SITEMAP_BUILD_OUT) {
    targets.push(process.env.SITEMAP_BUILD_OUT);
  } else {
    targets.push(buildOut);
  }

  for (const outPath of targets) {
    try {
      writeFileSync(outPath, xml, 'utf8');
      console.log(`Wrote ${unique.length} URLs to ${outPath}`);
    } catch (e) {
      if (outPath === buildOut) {
        console.warn(`Skipped ${buildOut} (${e.message}) — run flutter build web first or deploy via build-web-prod.ps1`);
      } else {
        throw e;
      }
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
