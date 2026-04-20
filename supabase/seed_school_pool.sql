-- ═══════════════════════════════════════════════════════════════════════════
-- BOOMTCHAK V3 — Seed du pool école (SQL)
-- À coller dans Supabase > SQL Editor > New query > Run
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Familles ─────────────────────────────────────────────────────────────────
insert into familles (id, nom, scope) values
  ('fam_base',       'Référentiel', 'school'),
  ('fam_euclidien',  'Euclidien',   'school'),
  ('fam_afrocubain', 'Afro-cubain', 'school'),
  ('fam_africain',   'Africain',    'school'),
  ('fam_bresilien',  'Brésilien',   'school'),
  ('fam_caraibe',    'Caraïbe',     'school'),
  ('fam_flamenco',   'Flamenco',    'school')
on conflict (id) do update set nom = excluded.nom, scope = 'school';

-- ── Patterns ─────────────────────────────────────────────────────────────────
insert into patterns (id, nom, sequence, pas, unite_temps, pas_par_mesure, familles_ids, encyclo_ref, scope, approved) values
  ('pulse1',  'Pulse',                  'X',                   1,  '1/4',  4,  array['fam_base'],                               null,       'school', true),
  ('bin2',    'Bin (1:2)',               'X.',                  2,  '1/4',  2,  array['fam_base'],                               null,       'school', true),
  ('ter3',    'Ter (1:3)',               'X..',                 3,  '1/4',  3,  array['fam_base'],                               null,       'school', true),
  ('fl4',     'Four on the Floor (2,4)', 'X.X.X.X.',            8,  '1/8',  8,  array['fam_base'],                               'fl4',      'school', true),
  ('offbeat', 'Off Beat (2,4)',           '.X.X.X.X',            8,  '1/8',  8,  array['fam_base'],                               'offbeat',  'school', true),
  ('pulse4',  'Pulse (4:4)',             'XXXX',                4,  '1/4',  4,  array['fam_base'],                               null,       'school', true),
  ('sync4',   'Double Up (2:4)',         '..XX',                4,  '1/4',  4,  array['fam_base'],                               null,       'school', true),
  ('silence', 'Silence',                 '....',                4,  '1/4',  4,  array['fam_base'],                               null,       'school', true),
  ('tres',    'Tresillo',                'X..X..X.',            8,  '1/8',  8,  array['fam_euclidien','fam_afrocubain'],          'tres',     'school', true),
  ('cinq',    'Cinquillo',               'X.XX.XX.',            8,  '1/8',  8,  array['fam_afrocubain'],                         'cinq',     'school', true),
  ('hab',     'Habanera',                'X..XX.X.',            8,  '1/8',  8,  array['fam_afrocubain'],                         'hab',      'school', true),
  ('afoxe',   'Afoxê / Bolero',          'X..X.X..',            8,  '1/8',  8,  array['fam_afrocubain','fam_africain'],           'afoxe',    'school', true),
  ('reggae',  'Clave Reggae',            '....X.X.',            8,  '1/8',  8,  array['fam_caraibe'],                            'reggae',   'school', true),
  ('son32',   'Son 3:2',                 'X..X..X...X.X...',   16,  '1/16', 16, array['fam_afrocubain'],                         'son32',    'school', true),
  ('son',     'Son (2:3)',               '..X.X...X..X..X.',   16,  '1/16', 16, array['fam_afrocubain'],                         'son',      'school', true),
  ('rum32',   'Rumba 3:2',               'X..X...X..X.X...',   16,  '1/16', 16, array['fam_afrocubain'],                         'rum32',    'school', true),
  ('shiko',   'Shiko',                   'X...X.X...X.X...',   16,  '1/16', 16, array['fam_africain'],                           'shiko',    'school', true),
  ('bossa',   'Bossa Nova',              'X..X..X...X..X..',   16,  '1/16', 16, array['fam_bresilien'],                          'bossa',    'school', true),
  ('gahu',    'Gahu',                    'X..X..X...X...X.',   16,  '1/16', 16, array['fam_africain'],                           'gahu',     'school', true),
  ('souk',    'Soukous',                 'X..X..X...XX....',   16,  '1/16', 16, array['fam_africain'],                           'souk',     'school', true),
  ('samba',   'Samba',                   'X..X.X.X..X.X.X.',   16,  '1/16', 16, array['fam_bresilien'],                          'samba',    'school', true),
  ('cascara', 'Cascara 3:2',             'X.XX.X.XX.X.XX.X',   16,  '1/16', 16, array['fam_afrocubain'],                         'cascara',  'school', true),
  ('tumbao',  'Tumbao',                  'X.XX.X.X.X.X.X.X',   16,  '1/16', 16, array['fam_afrocubain'],                         'tumbao',   'school', true),
  ('fume',    'Fume-fume',               'X.X.X..X.X..',       12,  '1/12', 12, array['fam_africain'],                           'fume',     'school', true),
  ('bembe',   'Bembé',                  'X.X.XX.X.X.X',       12,  '1/12', 12, array['fam_africain'],                           'bembe',    'school', true),
  ('solea',   'Soleá',                  '..X..X.X.X.X',       12,  '1/12', 12, array['fam_flamenco'],                           'solea',    'school', true)
on conflict (id) do update set
  nom = excluded.nom, sequence = excluded.sequence, familles_ids = excluded.familles_ids,
  scope = 'school', approved = true;

-- ── Grooves ──────────────────────────────────────────────────────────────────
insert into grooves (id, nom, familles_ids, band_defaut, tempo_min, tempo_max, tempo_defaut, vitesse_mult, layers, scope, approved) values
  ('salsa32',   'Salsa 3:2',  array['fam_afrocubain'], 'band_perc',    80,  360, 200, 2, '[{"id":"grave","patternId":"tres",    "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"aigu", "patternId":"son32",   "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"noise","patternId":"cascara","mute":false,"shift":0,"halfOn":false,"doubleOn":false}]', 'school', true),
  ('bossanova', 'Bossa Nova', array['fam_bresilien'],   'band_minimal', 60,  200, 160, 1, '[{"id":"grave","patternId":"sync4",  "mute":false,"shift":1,"halfOn":false,"doubleOn":false},{"id":"aigu", "patternId":"bossa",   "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"noise","patternId":"sync4",  "mute":false,"shift":0,"halfOn":false,"doubleOn":false}]', 'school', true),
  ('techno',    'Techno',     array[]::text[],          'band_electro', 80,  400, 260, 1, '[{"id":"grave","patternId":"fl4",    "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"aigu", "patternId":"tres",    "mute":true, "shift":0,"halfOn":false,"doubleOn":true },{"id":"noise","patternId":"offbeat","mute":false,"shift":0,"halfOn":false,"doubleOn":false}]', 'school', true),
  ('reggae',    'Reggae',     array['fam_caraibe'],     'band_rock',    60,  220, 200, 1, '[{"id":"grave","patternId":"reggae", "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"aigu", "patternId":"offbeat", "mute":false,"shift":0,"halfOn":true, "doubleOn":false},{"id":"noise","patternId":"sync4",  "mute":false,"shift":0,"halfOn":false,"doubleOn":false}]', 'school', true),
  ('dancehall', 'Dancehall',  array['fam_caraibe'],     'band_perc',    80,  320, 200, 2, '[{"id":"grave","patternId":"tres",   "mute":false,"shift":0,"halfOn":false,"doubleOn":false},{"id":"aigu", "patternId":"offbeat", "mute":false,"shift":0,"halfOn":true, "doubleOn":false},{"id":"noise","patternId":"hab",     "mute":false,"shift":0,"halfOn":false,"doubleOn":false}]', 'school', true)
on conflict (id) do update set
  nom = excluded.nom, familles_ids = excluded.familles_ids, layers = excluded.layers,
  scope = 'school', approved = true;

-- Vérification
select 'familles' as table_name, count(*) from familles where scope='school'
union all
select 'patterns', count(*) from patterns where scope='school'
union all
select 'grooves',  count(*) from grooves  where scope='school';
