#!/usr/bin/env node
/**
 * Verify every URL in web/sitemap.xml returns HTTP 200 on production.
 * Usage: node scripts/verify_sitemap.mjs [baseUrl]
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const base = process.argv[2] || 'https://dgyard.com';
const xml = readFileSync(join(__dirname, '..', 'web', 'sitemap.xml'), 'utf8');
const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);

let failed = 0;
for (const url of locs) {
  try {
    const res = await fetch(url, { method: 'HEAD', redirect: 'follow' });
    const ok = res.status === 200;
    console.log(`${ok ? 'OK' : 'FAIL'} ${res.status} ${url}`);
    if (!ok) failed++;
  } catch (e) {
    console.log(`FAIL ERR ${url} — ${e.message}`);
    failed++;
  }
}

console.log(`\nChecked ${locs.length} URLs — ${failed} failed`);
if (failed > 0) process.exit(1);
