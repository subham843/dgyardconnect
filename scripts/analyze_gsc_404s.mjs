#!/usr/bin/env node
/**
 * Parse GSC Coverage Drilldown XLSX (sharedStrings) and propose WooCommerce → Flutter redirects.
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const base = join(tmpdir(), 'gscxlsx');
const ss = readFileSync(join(base, 'xl/sharedStrings.xml'), 'utf8');
const strings = [...ss.matchAll(/<si>([\s\S]*?)<\/si>/g)].map((m) => {
  const ts = [...m[1].matchAll(/<t[^>]*>([^<]*)<\/t>/g)].map((x) => x[1]);
  return ts
    .join('')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"');
});

const urls = strings.filter((s) => /^https?:\/\//i.test(s));

// Canonical destinations already live on Flutter
const CCTV = '/store/category/cctv-camera-security';
const STORE = '/store';
const ACCESSORIES = '/store/category/computer-laptop-accessories';
const SMART = '/store/category/smart-home-automation';
const POWER = '/store/category/electrical-power-solutions';
const SERVICES = '/services';
const SUPPORT = '/support';
const PRIVACY = '/privacy-policy';
const CONTACT = '/contact';
const ABOUT = '/about';
const HOME = '/';

/** Exact product slug remaps when old WooCommerce slug ≈ new catalog slug */
const PRODUCT_EXACT = {
  '2-4mp-ir-dome-camera-20mtr': '/product/cp-plus-2-4mp-ir-dome-camera-dg-yard',
  '2-4mp-ir-bullet-camera-cp-plus': '/product/2-4mp-ir-bullet-camera-20mtr',
  '8ch-1080n-digital-video-recorder': '/product/16ch-1080n-digital-video-recorder',
  '16ch-5m-n-digital-video-recorder-cp-plus': '/product/16ch-1080n-digital-video-recorder',
};

function stripTrailingSlash(p) {
  if (!p || p === '/') return '/';
  return p.replace(/\/+$/, '');
}

function classify(raw) {
  const u = new URL(raw);
  const path = stripTrailingSlash(u.pathname);
  const host = u.host.toLowerCase();
  const q = u.searchParams;

  // Ignore junk
  if (path === '/&' || raw.includes('/&')) {
    return {
      source: path,
      destination: null,
      action: 'KEEP_404',
      reason: 'Malformed URL junk — do not redirect',
      match: 'none',
    };
  }

  // Auth / cart / API soft endpoints → closest UX page (not misleading products)
  if (path === '/cart' || path.endsWith('/cart')) {
    return {
      source: '/cart',
      destination: '/store/cart',
      action: '301',
      reason: 'Old WooCommerce cart → Flutter store cart',
      match: 'functional',
    };
  }
  if (path.startsWith('/auth/')) {
    return {
      source: '/auth/**',
      destination: '/login',
      action: '301',
      reason: 'Legacy Next/Woo auth callback → Flutter login',
      match: 'functional',
    };
  }
  if (path.startsWith('/api/')) {
    return {
      source: path,
      destination: null,
      action: 'KEEP_404',
      reason: 'Legacy API endpoint — intentional 404 (no public page)',
      match: 'none',
    };
  }
  if (path === '/quotation') {
    return {
      source: '/quotation',
      destination: '/calculator',
      action: '301',
      reason: 'Old quotation tool → public BOQ calculators',
      match: 'functional',
    };
  }
  if (path === '/privacy-policy') {
    return {
      source: '/privacy-policy',
      destination: PRIVACY,
      action: 'ALREADY_OK',
      reason: 'Route exists on Flutter — soft 404 only if SPA shell; no redirect needed',
      match: 'exact',
    };
  }
  if (path === '/' || path === '') {
    return {
      source: '/',
      destination: HOME,
      action: 'ALREADY_OK',
      reason: 'Homepage exists — www host issue separately',
      match: 'exact',
    };
  }
  if (path === '/faqs' || path === '/faq') {
    return {
      source: '/faqs',
      destination: SUPPORT,
      action: '301',
      reason: 'FAQ content retired; support/help center is closest',
      match: 'close',
    };
  }
  if (path === '/blog') {
    return {
      source: '/blog',
      destination: '/services',
      action: '301',
      reason: 'Old blog index retired; avoid soft homepage — services is topical hub. Prefer keep 404 if blog index returns soon.',
      match: 'close',
    };
  }
  if (path.startsWith('/author/')) {
    return {
      source: '/author/**',
      destination: null,
      action: 'KEEP_404',
      reason: 'Author archives have no Flutter equivalent — keep 404',
      match: 'none',
    };
  }

  // SMM microsite (placeholder/lorem posts) — no equivalent
  if (path === '/smm' || path.startsWith('/smm/')) {
    if (path === '/smm' || path === '/smm/about') {
      return {
        source: path,
        destination: '/services',
        action: '301',
        reason: 'Old SMM microsite → digital services section',
        match: 'close',
      };
    }
    if (path === '/smm/contact') {
      return {
        source: '/smm/contact',
        destination: CONTACT,
        action: '301',
        reason: 'SMM contact → main contact',
        match: 'functional',
      };
    }
    if (path.startsWith('/smm/blog')) {
      return {
        source: path,
        destination: null,
        action: 'KEEP_404',
        reason: 'SMM placeholder/lorem blog posts — no indexable equivalent',
        match: 'none',
      };
    }
    if (path.startsWith('/smm/change')) {
      return {
        source: path,
        destination: null,
        action: 'KEEP_404',
        reason: 'Internal/legacy SMM admin path — keep 404',
        match: 'none',
      };
    }
    return {
      source: path,
      destination: '/services',
      action: '301',
      reason: 'Misc SMM path → services',
      match: 'close',
    };
  }

  // WordPress category blog vs product category
  if (path === '/category/home-automation') {
    return {
      source: path,
      destination: SMART,
      action: '301',
      reason: 'WP blog category → smart home store category',
      match: 'close',
    };
  }
  if (path === '/category/cctv-camera') {
    return {
      source: path,
      destination: CCTV,
      action: '301',
      reason: 'WP blog category → CCTV store category',
      match: 'close',
    };
  }

  // Long-form promo posts
  if (path === '/securing-your-world-the-power-of-professional-cctv-services') {
    return {
      source: path,
      destination: SERVICES,
      action: '301',
      reason: 'CCTV services marketing post → services page',
      match: 'close',
    };
  }
  if (path === '/transforming-houses-into-smart-homes-the-power-of-home-automation') {
    return {
      source: path,
      destination: SMART,
      action: '301',
      reason: 'Home automation marketing post → smart-home category',
      match: 'close',
    };
  }

  // Product categories (WooCommerce)
  if (path.startsWith('/product-category/')) {
    const rest = path.replace('/product-category/', '');
    // Query-only add-to-cart variants collapse to same rule via globs
    if (rest.startsWith('analog-hd-camera-kit')) {
      return {
        source: path + (u.search || ''),
        destination: CCTV,
        action: '301',
        reason: 'HD camera kit catalog → CCTV category (kits not SKU-mirrored 1:1)',
        match: 'category',
      };
    }
    if (rest.startsWith('analog-hd-camera')) {
      return {
        source: path + (u.search || ''),
        destination: CCTV,
        action: '301',
        reason: 'Analog HD camera taxonomy → CCTV category',
        match: 'category',
      };
    }
    if (rest.startsWith('accessories/power-supply')) {
      return {
        source: path,
        destination: POWER,
        action: '301',
        reason: 'Power-supply accessories → electrical/power category',
        match: 'category',
      };
    }
    if (rest.startsWith('accessories')) {
      return {
        source: path + (u.search || ''),
        destination: ACCESSORIES,
        action: '301',
        reason: 'Generic accessories → computer/IT accessories category',
        match: 'category',
      };
    }
    return {
      source: path,
      destination: STORE,
      action: '301',
      reason: 'Other Woo category → store',
      match: 'category',
    };
  }

  // Products
  if (path.startsWith('/product/')) {
    const slug = path.replace('/product/', '');
    if (PRODUCT_EXACT[slug]) {
      return {
        source: path,
        destination: PRODUCT_EXACT[slug],
        action: '301',
        reason: `Near-match product slug remap → ${PRODUCT_EXACT[slug]}`,
        match: 'product',
      };
    }
    // Camera kits / multi-SKU bundles no longer listed
    if (
      slug.includes('camera-set') ||
      slug.includes('dvr-kit') ||
      slug.includes('outdoor-bullet-camera') ||
      slug.includes('night-vision-any')
    ) {
      return {
        source: path + (u.search ? '?…' : ''),
        destination: CCTV,
        action: '301',
        reason: 'Discontinued kit/bundle SKU — no exact product; CCTV category safest',
        match: 'category',
      };
    }
    return {
      source: path,
      destination: CCTV,
      action: '301',
      reason: 'Removed Woo product without catalog twin → CCTV category (avoid homepage)',
      match: 'category',
    };
  }

  return {
    source: path + (u.search || ''),
    destination: null,
    action: 'KEEP_404',
    reason: 'No confident mapping',
    match: 'none',
    host,
  };
}

const rows = [];
const seen = new Set();
for (const raw of urls) {
  const c = classify(raw);
  const key = `${c.action}|${c.source}|${c.destination}`;
  if (seen.has(key)) continue;
  seen.add(key);
  rows.push({ ...c, sample: raw });
}

rows.sort((a, b) => a.action.localeCompare(b.action) || a.source.localeCompare(b.source));

const outDir = join(process.cwd(), 'docs');
mkdirSync(outDir, { recursive: true });

const mappingPath = join(outDir, 'GSC_404_REDIRECT_MAP.md');
let md = `# GSC 404 → Flutter redirect map\n\n`;
md += `Source: Google Search Console Coverage Drilldown (Not found 404) — 2026-07-08\n\n`;
md += `Unique URL samples parsed: **${urls.length}**\n\n`;
md += `## Summary\n\n`;
const counts = Object.create(null);
for (const r of rows) counts[r.action] = (counts[r.action] || 0) + 1;
for (const [k, v] of Object.entries(counts)) md += `- **${k}**: ${v}\n`;
md += `\n## Mapping table\n\n`;
md += `| Old path (pattern) | Action | New destination | Match | Why |\n|---|---|---|---|---|\n`;
for (const r of rows) {
  md += `| \`${r.source}\` | ${r.action} | ${r.destination ? `\`${r.destination}\`` : '—'} | ${r.match} | ${r.reason} |\n`;
}
md += `\n## Sample URLs from GSC export\n\n`;
for (const u of urls.sort()) md += `- ${u}\n`;

writeFileSync(mappingPath, md, 'utf8');
console.log(JSON.stringify({ uniqueRules: rows.length, urls: urls.length, counts, mappingPath }, null, 2));
console.log('\n--- RULES ---');
for (const r of rows) {
  console.log(`${r.action.padEnd(12)} ${r.source.padEnd(60)} -> ${r.destination || '(404)'} | ${r.reason}`);
}
