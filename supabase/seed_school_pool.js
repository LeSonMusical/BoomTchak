#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════════════════
// BOOMTCHAK V3 — Script de seed du pool école
//
// Pousse tous les patterns/grooves/familles/encyclo PTK_DEFAULT dans
// Supabase avec scope='school' et approved=true.
//
// Usage :
//   node supabase/seed_school_pool.js
//
// Prérequis :
//   - Node.js v18+ (fetch intégré)
//   - Variables d'environnement configurées ci-dessous
//   - Le schéma SQL (schema.sql) déjà exécuté dans Supabase
//   - La clé SERVICE ROLE (pas la clé anon) — Settings > API > service_role
// ═══════════════════════════════════════════════════════════════════════════

// ── Config ── À remplir avant de lancer ─────────────────────────────────────
const SUPABASE_URL          = process.env.SUPABASE_URL          || 'https://XXXX.supabase.co';
const SUPABASE_SERVICE_KEY  = process.env.SUPABASE_SERVICE_KEY  || 'VOTRE_SERVICE_ROLE_KEY';
const MX_USER_ID            = process.env.MX_USER_ID            || null; // UUID du profil MX (optionnel)

// ── Données PTK_DEFAULT (miroir de index.html) ───────────────────────────────

const FAMILLES = [
  { id:'fam_base',       nom:'Référentiel'  },
  { id:'fam_euclidien',  nom:'Euclidien'    },
  { id:'fam_afrocubain', nom:'Afro-cubain'  },
  { id:'fam_africain',   nom:'Africain'     },
  { id:'fam_bresilien',  nom:'Brésilien'    },
  { id:'fam_caraibe',    nom:'Caraïbe'      },
  { id:'fam_flamenco',   nom:'Flamenco'     },
];

const PATTERNS = [
  { id:'pulse1',  nom:'Pulse',                   familles_ids:['fam_base'],                                sequence:'X',                   pas:1,  unite_temps:'1/4',  pas_par_mesure:4  },
  { id:'bin2',    nom:'Bin (1:2)',                familles_ids:['fam_base'],                                sequence:'X.',                  pas:2,  unite_temps:'1/4',  pas_par_mesure:2  },
  { id:'ter3',    nom:'Ter (1:3)',                familles_ids:['fam_base'],                                sequence:'X..',                 pas:3,  unite_temps:'1/4',  pas_par_mesure:3  },
  { id:'fl4',     nom:'Four on the Floor (2,4)',  familles_ids:['fam_base'],                                sequence:'X.X.X.X.',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'fl4'     },
  { id:'offbeat', nom:'Off Beat (2,4)',            familles_ids:['fam_base'],                                sequence:'.X.X.X.X',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'offbeat' },
  { id:'pulse4',  nom:'Pulse (4:4)',              familles_ids:['fam_base'],                                sequence:'XXXX',                pas:4,  unite_temps:'1/4',  pas_par_mesure:4  },
  { id:'sync4',   nom:'Double Up (2:4)',          familles_ids:['fam_base'],                                sequence:'..XX',                pas:4,  unite_temps:'1/4',  pas_par_mesure:4  },
  { id:'silence', nom:'Silence',                  familles_ids:['fam_base'],                                sequence:'....',                pas:4,  unite_temps:'1/4',  pas_par_mesure:4  },
  { id:'tres',    nom:'Tresillo',                 familles_ids:['fam_euclidien','fam_afrocubain'],           sequence:'X..X..X.',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'tres'    },
  { id:'cinq',    nom:'Cinquillo',                familles_ids:['fam_afrocubain'],                          sequence:'X.XX.XX.',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'cinq'    },
  { id:'hab',     nom:'Habanera',                 familles_ids:['fam_afrocubain'],                          sequence:'X..XX.X.',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'hab'     },
  { id:'afoxe',   nom:'Afoxê / Bolero',           familles_ids:['fam_afrocubain','fam_africain'],           sequence:'X..X.X..',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'afoxe'   },
  { id:'reggae',  nom:'Clave Reggae',             familles_ids:['fam_caraibe'],                             sequence:'....X.X.',            pas:8,  unite_temps:'1/8',  pas_par_mesure:8,  encyclo_ref:'reggae'  },
  { id:'son32',   nom:'Son 3:2',                  familles_ids:['fam_afrocubain'],                          sequence:'X..X..X...X.X...',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'son32'   },
  { id:'son',     nom:'Son (2:3)',                familles_ids:['fam_afrocubain'],                          sequence:'..X.X...X..X..X.',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'son'     },
  { id:'rum32',   nom:'Rumba 3:2',               familles_ids:['fam_afrocubain'],                          sequence:'X..X...X..X.X...',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'rum32'   },
  { id:'shiko',   nom:'Shiko',                   familles_ids:['fam_africain'],                            sequence:'X...X.X...X.X...',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'shiko'   },
  { id:'bossa',   nom:'Bossa Nova',               familles_ids:['fam_bresilien'],                           sequence:'X..X..X...X..X..',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'bossa'   },
  { id:'gahu',    nom:'Gahu',                     familles_ids:['fam_africain'],                            sequence:'X..X..X...X...X.',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'gahu'    },
  { id:'souk',    nom:'Soukous',                  familles_ids:['fam_africain'],                            sequence:'X..X..X...XX....',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'souk'    },
  { id:'samba',   nom:'Samba',                    familles_ids:['fam_bresilien'],                           sequence:'X..X.X.X..X.X.X.',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'samba'   },
  { id:'cascara', nom:'Cascara 3:2',              familles_ids:['fam_afrocubain'],                          sequence:'X.XX.X.XX.X.XX.X',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'cascara' },
  { id:'tumbao',  nom:'Tumbao',                   familles_ids:['fam_afrocubain'],                          sequence:'X.XX.X.X.X.X.X.X',   pas:16, unite_temps:'1/16', pas_par_mesure:16, encyclo_ref:'tumbao'  },
  { id:'fume',    nom:'Fume-fume',                familles_ids:['fam_africain'],                            sequence:'X.X.X..X.X..',       pas:12, unite_temps:'1/12', pas_par_mesure:12, encyclo_ref:'fume'    },
  { id:'bembe',   nom:'Bembé',                   familles_ids:['fam_africain'],                            sequence:'X.X.XX.X.X.X',       pas:12, unite_temps:'1/12', pas_par_mesure:12, encyclo_ref:'bembe'   },
  { id:'solea',   nom:'Soleá',                   familles_ids:['fam_flamenco'],                            sequence:'..X..X.X.X.X',       pas:12, unite_temps:'1/12', pas_par_mesure:12, encyclo_ref:'solea'   },
];

const GROOVES = [
  { id:'salsa32',   nom:'Salsa 3:2',  familles_ids:['fam_afrocubain'], band_defaut:'band_perc',    tempo_min:80,  tempo_max:360, tempo_defaut:200, vitesse_mult:2,
    layers:[{id:'grave',patternId:'tres',    mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'aigu', patternId:'son32',   mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'noise',patternId:'cascara', mute:false,shift:0,halfOn:false,doubleOn:false}] },
  { id:'bossanova', nom:'Bossa Nova', familles_ids:['fam_bresilien'],   band_defaut:'band_minimal', tempo_min:60,  tempo_max:200, tempo_defaut:160, vitesse_mult:1,
    layers:[{id:'grave',patternId:'sync4',   mute:false,shift:1,halfOn:false,doubleOn:false},
            {id:'aigu', patternId:'bossa',   mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'noise',patternId:'sync4',   mute:false,shift:0,halfOn:false,doubleOn:false}] },
  { id:'techno',    nom:'Techno',     familles_ids:[],                  band_defaut:'band_electro', tempo_min:80,  tempo_max:400, tempo_defaut:260, vitesse_mult:1,
    layers:[{id:'grave',patternId:'fl4',     mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'aigu', patternId:'tres',    mute:true, shift:0,halfOn:false,doubleOn:true },
            {id:'noise',patternId:'offbeat', mute:false,shift:0,halfOn:false,doubleOn:false}] },
  { id:'reggae',    nom:'Reggae',     familles_ids:['fam_caraibe'],     band_defaut:'band_rock',    tempo_min:60,  tempo_max:220, tempo_defaut:200, vitesse_mult:1,
    layers:[{id:'grave',patternId:'reggae',  mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'aigu', patternId:'offbeat', mute:false,shift:0,halfOn:true, doubleOn:false},
            {id:'noise',patternId:'sync4',   mute:false,shift:0,halfOn:false,doubleOn:false}] },
  { id:'dancehall', nom:'Dancehall',  familles_ids:['fam_caraibe'],     band_defaut:'band_perc',    tempo_min:80,  tempo_max:320, tempo_defaut:200, vitesse_mult:2,
    layers:[{id:'grave',patternId:'tres',    mute:false,shift:0,halfOn:false,doubleOn:false},
            {id:'aigu', patternId:'offbeat', mute:false,shift:0,halfOn:true, doubleOn:false},
            {id:'noise',patternId:'hab',     mute:false,shift:0,halfOn:false,doubleOn:false}] },
];

// ── Helpers ───────────────────────────────────────────────────────────────────
async function upsert(table, rows) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(rows),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`[${table}] ${res.status}: ${txt}`);
  }
}

// ── Seed ─────────────────────────────────────────────────────────────────────
async function seed() {
  console.log('🎵 BoomTchak V3 — Seed du pool école\n');

  if (SUPABASE_URL.includes('XXXX') || SUPABASE_SERVICE_KEY.includes('VOTRE')) {
    console.error('❌ Configurez SUPABASE_URL et SUPABASE_SERVICE_KEY avant de lancer ce script.');
    console.error('   Vous les trouverez dans Supabase > Settings > API\n');
    process.exit(1);
  }

  // Familles
  process.stdout.write('  Familles…   ');
  await upsert('familles', FAMILLES.map(f => ({
    ...f,
    scope: 'school',
    owner_id: MX_USER_ID,
  })));
  console.log(`✓ ${FAMILLES.length} familles`);

  // Patterns
  process.stdout.write('  Patterns…   ');
  await upsert('patterns', PATTERNS.map(p => ({
    ...p,
    scope: 'school',
    approved: true,
    owner_id: MX_USER_ID,
  })));
  console.log(`✓ ${PATTERNS.length} patterns`);

  // Grooves
  process.stdout.write('  Grooves…    ');
  await upsert('grooves', GROOVES.map(g => ({
    ...g,
    layers: JSON.stringify(g.layers), // jsonb
    scope: 'school',
    approved: true,
    owner_id: MX_USER_ID,
  })));
  console.log(`✓ ${GROOVES.length} grooves`);

  console.log('\n✅ Seed terminé. Le pool école est prêt.');
  console.log('   Connectez-vous dans l\'app pour vérifier la synchronisation.\n');
}

seed().catch(e => {
  console.error('\n❌ Erreur :', e.message);
  process.exit(1);
});
