#!/usr/bin/env node
// Génère le SQL d'insertion pour la table encyclo
// Usage: node supabase/generate_encyclo_seed.js >> supabase/seed_school_pool.sql
//    ou: node supabase/generate_encyclo_seed.js | pbcopy  (macOS)

const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');

// Extraire le bloc ENCYCLO entre "const ENCYCLO = {" et "};"
const start = html.indexOf('const ENCYCLO = {');
const end = html.indexOf('\n};', start) + 3;
const encycloSrc = html.slice(start, end);

// Évaluer dans un contexte isolé
const fn = new Function(encycloSrc + '\nreturn ENCYCLO;');
const ENCYCLO = fn();

function pgStr(s) {
  // Dollar-quoting pour éviter les problèmes d'apostrophes/guillemets
  return '$$' + s + '$$';
}

function pgJson(arr) {
  return '$$' + JSON.stringify(arr) + '$$::jsonb';
}

const rows = Object.entries(ENCYCLO).map(([key, entry]) => {
  const chapo = pgStr(entry.chapo || '');
  const bullets = pgJson(entry.bullets || []);
  return `('${key}',\n ${chapo},\n ${bullets},\n 'school', true)`;
});

const sql = `
-- ── Encyclopédie ─────────────────────────────────────────────────────────────
insert into encyclo (key, chapo, bullets, scope, approved) values
${rows.join(',\n')}
on conflict (key) do update set
  chapo = excluded.chapo, bullets = excluded.bullets,
  scope = 'school', approved = true, updated_at = now();
`;

process.stdout.write(sql);
