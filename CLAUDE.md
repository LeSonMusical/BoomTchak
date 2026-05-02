# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~8600 lignes), vanilla JS, Supabase.
Lire `BoomTchak_v3_bible.md` et `BoomTchak_Explain.md` avant toute modification.

## Règles de collaboration
- Lamberio = product owner. Questions archi importantes → soumettre AVANT de coder.
- Langue : français. Variables/fonctions : camelCase anglais.
- Version `MAJEUR.MINEUR.PATCH` bumpée à chaque commit (dans `<span class="app-version">`).

## Règles CRUD (bible — à respecter impérativement)

**Règle 1 — Symétrie TX/MX**
TX a les mêmes capacités d'édition que MX. La différence : ses modifications apparaissent dans la section "Soumettre" (au lieu de "Publier") et doivent être validées par MX pour intégrer la base commune.

**Règle 2 — Aucune écriture DB directe**
Toute modification de la base doit passer par `buildPublishSection` (MX) ou `buildApprobationsSection` (MX approbation TX). Aucun appel Supabase POST/PATCH/DELETE ne doit être déclenché depuis une action UI sans étape de confirmation dans l'un de ces deux panneaux.

**Règle 3 — Homogénéité CRUD**
Tous les types d'items (patterns, grooves, encyclopédie, familles) suivent la même procédure CRUD avec le même UX design.

**Règle 4 — Tag famille ≠ modif item**
Une modification de tag famille est un phénomène distinct d'une modification de contenu (séquence, nom, couches…). Les deux ne se mélangent pas dans les panneaux Soumettre/Publier. Si un item a à la fois une modif contenu ET une modif tag, la soumission/approbation se fait en 2 étapes séparées. Les items tag-only apparaissent dans une section "Tags" dédiée, jamais dans "Patterns" ou "Grooves".

**Règle 5 — Approuver = approuver ET publier**
Le verbe "Publier" est réservé aux modifications MX (qui publient directement en DB). Pour les modifications TX, le verbe est "Approuver" (ou "Soumettre" côté TX). Approuver une modification TX équivaut à l'approuver et la publier simultanément — il n'y a pas d'étape intermédiaire entre approbation et publication.

### Conformité par item (post v3.7.0)

| Item | TX Create | TX Update | TX Delete | MX Create | MX Update | MX Delete |
|---|---|---|---|---|---|---|
| Pattern | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Groove | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Encyclopédie | ✅ | ✅ ↺ Renvoyer | ❌ GAP | ✅ publish | ✅ publish | ❌ GAP |
| Famille école | n/a | ✅ _pendingRename→push | n/a | ✅ localDirty→publish | ✅ localDirty→publish | ✅ pendingDel |
| Famille teacher | ✅ auto-push item | ✅ _pendingRename→push | ✅ local | n/a | n/a | n/a |
| Tag famille | ✅ section Tags | ✅ section Tags | n/a | ✅ section Tags | ✅ section Tags | n/a |
| Metro preset | ✅ via lib-panel | ✅ via modal sig ✎ | ✅ via modal sig ✎ | ✅ publish | ✅ publish | ✅ direct |
| Famille métro | n/a | ✅ MX via modal sig ✎ | ✅ MX via modal sig ✎ | ✅ MX direct DB | n/a | n/a |

### Gaps connus (à traiter)
- `GAP_ENC_DEL` : Pas de delete encyclopédie TX ni MX (hors scope actuel)

## Règle de déploiement (OBLIGATOIRE — à chaque session)
Après chaque push de branche feature :
1. Créer une PR draft si elle n'existe pas
2. **Merger immédiatement la PR vers `main`** — l'utilisateur teste depuis GitHub Pages
3. `git push origin main`
4. Resynchroniser la branche de travail : `git checkout feature-branch && git merge main`

Ne jamais laisser `main` en retard sur la branche de travail.

## Branche de travail
Merger vers : `main` après chaque session

## Stack
- Frontend : HTML/CSS/JS vanilla (zéro dépendance)
- Backend : Supabase REST API (fetch natif, pas de SDK)
- Auth : Google OAuth implicit flow
- Déploiement : GitHub Pages (fichier statique `index.html`)

## Fichiers de référence
- `index.html` — application complète (~8600 lignes)
- `BoomTchak_Explain.md` — référence complète (pédagogie + UX + technique + roadmap)
- `BoomTchak_v3_bible.md` — référence technique v3 (DB, RLS, workflows TX/MX)
- `supabase/schema.sql` — schéma Supabase (inclut toutes les migrations jusqu'à v3.7.0)
- `supabase/seed_school_pool.sql` — données initiales école

## Version courante
**v3.7.0** (session 2026-05-02)

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.7.0 | Familles métronome dynamiques : table `metro_familles` en DB, colonnes `familles_ids`+`ordre` sur `metro_presets` ; modal sig étendu avec modes gérer/réordonner/tag complets comme groove/pattern |
| v3.6.5 | Correctifs drag-reorder : splice index, famille sélectionnée mémorisée, propagation groove→pattern, dark mode drag-over, sentinel end-zone |
| v3.6.3 | Colonnes `ordre` sur patterns/grooves/familles ; fetch trié ; sbPushSchoolOrder/FamOrder avec return=representation |
| v3.5.3 | Son volet : preset+volume toujours visibles (2 rangées header) ; Encyclopédie : champ `category` sur ENCYCLO_MISC + filtre catégorie (Appli/Concepts/Grooves/Patterns) |

## Tâches prioritaires (prochaine session)

### Migration DB v3.7.0 (OBLIGATOIRE avant tout test)
Exécuter dans Supabase SQL Editor :
```sql
create table if not exists public.metro_familles (
  id text primary key, nom text not null,
  scope text not null default 'school' check (scope in ('school','teacher')),
  owner_id uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(), ordre int default 0
);
alter table public.metro_familles enable row level security;
create policy "Lecture metro_familles" on public.metro_familles for select
  using (scope='school' or owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Insert metro_familles" on public.metro_familles for insert with check (auth.uid() is not null);
create policy "Update metro_familles" on public.metro_familles for update
  using (owner_id=auth.uid() or public.current_role_name()='mx');
create policy "Delete metro_familles" on public.metro_familles for delete
  using (owner_id=auth.uid() or public.current_role_name()='mx');

alter table public.metro_presets
  add column if not exists familles_ids text[] default '{}',
  add column if not exists ordre int default 0;
```
Puis se connecter en MX → le seed automatique des 4 familles et 14 presets se déclenche.

### Chantiers suivants
1. **G1 Fork item école** — TX modifie un item école → copie automatique en source:'teacher'
2. **G7 Raison de refus** — MX saisit un message lors du rejet, TX le voit dans le toast
3. **Nettoyage lib-panel-metro** — remplacer `buildMetroMgrModal` / `lib-panel-metro` par le modal sig (qui remplit désormais le même rôle)

## Résolu (session 2026-05-02)
- ✅ **Familles métronome dynamiques** — `metro_familles` DB, `familles_ids` sur presets, modal sig avec modes gérer/réordonner/tag, seed automatique MX, `sbPushSchoolMetroFamOrder` / `sbPushSchoolMetroOrder`

## Résolu (session 2026-05-01)
- ✅ **Recherche temps réel** — champ search dans panels Patterns/Grooves/Bands (filtre par nom)
- ✅ **Export MIDI** — modal note+canal par couche, tempo, signature ; SMF Type 0, 96 PPQ (menu `···`)
- ✅ **Ordre familles MX** — `sbPushSchoolFamOrder()` après drag-drop ; fetch trié `ordre.asc`
- ✅ **Mute/unmute couches** — tap court btn-vol bascule toutes les couches groove
- ✅ **Subdivision métro indépendante** — `stepSec = (60/spm)×spb/sub` ; patterns non affectés
- ✅ **Correctif critique attachEvents** — modal MIDI déplacé avant `<script>` (null crash fixé)
- ✅ **Mode gérer/réordonner openPresetModal** — groove/pattern : rename, delete, tag, drag-reorder dans le modal

## Résolu (session 2026-04-28)
- ✅ **G0** — `initAuth()` invalide `authSession` si `authProfile` null
- ✅ **G8** — Ordre patterns/grooves persisté via `sbPushSchoolOrder()` après drag-drop
- ✅ **GAP_FAM_RENAME_TX** — Renommage TX soumis via `_pendingRename` + section "Tags familles"

## Architecture `openPresetModal` (état v3.7.0)

```
openPresetModal(cfg)
  cfg.type : 'groove' | 'pattern' | 'sig' | 'sound' | 'band'

  États communs à groove/pattern/sig :
    manageMode  (✎) : rename/delete items + CRUD tags famille
    reorderMode (☰) : drag-drop items et familles, persistance DB
    paletteMode : colonne gauche = sélecteur de famille à tagger

  Fonctions internes :
    getFams()           → familles filtrées selon type
    getFilteredItems()  → items filtrés (famFilter + searchQuery)
    pmNewFamille()      → crée famille (metro_familles ou familles selon type)
    pmDeleteFam(fam)    → supprime famille + détache les tags
    pmDropFam(src,tgt)  → réordonne familles + persist DB
    pmDrop(src,tgt)     → réordonne items + persist DB
    pmAddTag(item,famId)   → ajoute tag (PATCH DB direct pour sig/MX)
    pmRemoveTag(item,famId)→ retire tag
    pmStartRename(el,item) → rename inline item
    _pmStartRenameMetroFam(el,fam) → rename inline famille métro

  Helpers globaux pour sig :
    getMetroFamilles()  → packCours.metroFamilles ou fallback SIG_FAMILLES
    getMetroFamille(id) → lookup une famille métro

  Persistance ordre :
    sbPushSchoolFamOrder()      → familles école (patterns/grooves)
    sbPushSchoolMetroFamOrder() → familles métronome
    sbPushSchoolOrder(type)     → items patterns/grooves
    sbPushSchoolMetroOrder()    → items metro_presets
```

## Futur chantier — Metro comme pattern (à valider avec Lamberio)

**Concept :** Remplacer les signatures codées en dur par des presets de métronome éditables,
où les coups du métronome sont encodés comme un pattern (comme les patterns de grooves).

**Motivation :** Les signatures asymétriques (7/8, 11/8…) ont des regroupements variables
(2+2+3, 3+2+2, 2+3+2…) non représentables avec l'architecture actuelle (séparateur fixe toutes
les N croches). Un preset permettrait d'encoder exactement où tombent les accents, les temps et
les subdivisions.

**Prérequis :** Valider le modèle de données avec Lamberio avant tout codage.

## Conventions
- Commentaires en français, code en anglais
- Pas de framework, pas de bibliothèque externe
- Mobile-first (testé sur smartphone)
- Écriture de gros fichiers : utiliser scripts bash/heredoc, jamais le Write tool direct


## Règles de collaboration
- Lamberio = product owner. Questions archi importantes → soumettre AVANT de coder.
- Langue : français. Variables/fonctions : camelCase anglais.
- Version `MAJEUR.MINEUR.PATCH` bumpée à chaque commit (dans `<span class="app-version">`).

## Règles CRUD (bible — à respecter impérativement)

**Règle 1 — Symétrie TX/MX**
TX a les mêmes capacités d'édition que MX. La différence : ses modifications apparaissent dans la section "Soumettre" (au lieu de "Publier") et doivent être validées par MX pour intégrer la base commune.

**Règle 2 — Aucune écriture DB directe**
Toute modification de la base doit passer par `buildPublishSection` (MX) ou `buildApprobationsSection` (MX approbation TX). Aucun appel Supabase POST/PATCH/DELETE ne doit être déclenché depuis une action UI sans étape de confirmation dans l'un de ces deux panneaux.

**Règle 3 — Homogénéité CRUD**
Tous les types d'items (patterns, grooves, encyclopédie, familles) suivent la même procédure CRUD avec le même UX design.

**Règle 4 — Tag famille ≠ modif item**
Une modification de tag famille est un phénomène distinct d'une modification de contenu (séquence, nom, couches…). Les deux ne se mélangent pas dans les panneaux Soumettre/Publier. Si un item a à la fois une modif contenu ET une modif tag, la soumission/approbation se fait en 2 étapes séparées. Les items tag-only apparaissent dans une section "Tags" dédiée, jamais dans "Patterns" ou "Grooves".

**Règle 5 — Approuver = approuver ET publier**
Le verbe "Publier" est réservé aux modifications MX (qui publient directement en DB). Pour les modifications TX, le verbe est "Approuver" (ou "Soumettre" côté TX). Approuver une modification TX équivaut à l'approuver et la publier simultanément — il n'y a pas d'étape intermédiaire entre approbation et publication.

### Conformité par item (post v3.4.9)

| Item | TX Create | TX Update | TX Delete | MX Create | MX Update | MX Delete |
|---|---|---|---|---|---|---|
| Pattern | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Groove | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Encyclopédie | ✅ | ✅ ↺ Renvoyer | ❌ GAP | ✅ publish | ✅ publish | ❌ GAP |
| Famille école | n/a | ✅ _pendingRename→push | n/a | ✅ localDirty→publish | ✅ localDirty→publish | ✅ pendingDel |
| Famille teacher | ✅ auto-push item | ✅ _pendingRename→push | ✅ local | n/a | n/a | n/a |
| Tag famille | ✅ section Tags | ✅ section Tags | n/a | ✅ section Tags | ✅ section Tags | n/a |

### Gaps connus (à traiter)
- `GAP_ENC_DEL` : Pas de delete encyclopédie TX ni MX (hors scope actuel)

## Règle de déploiement (OBLIGATOIRE — à chaque session)
Après chaque push de branche feature :
1. Créer une PR draft si elle n'existe pas
2. **Merger immédiatement la PR vers `main`** — l'utilisateur teste depuis GitHub Pages
3. `git push origin main`
4. Resynchroniser la branche de travail : `git checkout feature-branch && git merge main`

Ne jamais laisser `main` en retard sur la branche de travail.

## Branche de travail
Merger vers : `main` après chaque session

## Stack
- Frontend : HTML/CSS/JS vanilla (zéro dépendance)
- Backend : Supabase REST API (fetch natif, pas de SDK)
- Auth : Google OAuth implicit flow
- Déploiement : GitHub Pages (fichier statique `index.html`)

## Fichiers de référence
- `index.html` — application complète
- `BoomTchak_Explain.md` — référence complète (pédagogie + UX + technique + roadmap)
- `BoomTchak_v3_bible.md` — référence technique v3 (DB, RLS, workflows TX/MX)
- `supabase/schema.sql` — schéma Supabase
- `supabase/seed_school_pool.sql` — données initiales école

## Version courante
**v3.7.0** (session 2026-05-02)

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.7.0 | Familles métronome dynamiques : table `metro_familles` en DB, colonnes `familles_ids`+`ordre` sur `metro_presets` ; modal sig étendu avec modes gérer/réordonner/tag complets comme groove/pattern |
| v3.6.5 | Correctifs drag-reorder : splice index, famille sélectionnée mémorisée, propagation groove→pattern, dark mode drag-over, sentinel end-zone |
| v3.6.3 | Colonnes `ordre` sur patterns/grooves/familles ; fetch trié ; sbPushSchoolOrder/FamOrder avec return=representation |
| v3.5.3 | Son volet : preset+volume toujours visibles (2 rangées header) ; Encyclopédie : champ `category` sur ENCYCLO_MISC + filtre catégorie (Appli/Concepts/Grooves/Patterns) |

## Tâches prioritaires (prochaine session)
1. **Migration DB v3.7.0** — Exécuter dans Supabase SQL Editor (voir ci-dessous)
2. **G1 Fork item école** — TX modifie un item école → copie automatique en source:'teacher'
3. **G7 Raison de refus** — MX saisit un message lors du rejet, TX le voit dans le toast

## Spec : Mode "gérer" dans openPresetModal (prochaine session)

### Objectif
Intégrer les opérations CRUD (tag, rename, delete, reorder) directement dans le modal de sélection pour Grooves et Patterns. Supprimer les lib-panels Grooves et Patterns (et leurs boutons ≡).

### UX — 3 états du modal
Header : `[label] [✎ gérer] [↕ réordonner] [✕]`

**État normal (sélection)**
- Left : familles (filtre passif)
- Right : items — tap = sélectionner et fermer

**État "gérer" (toggle ✎)**
- Left : familles deviennent palette active (cliquables pour ajouter tag)
- Right : items étendus sur 2 lignes :
  - L1 : `[nom (tap inline = renommer)] [🗑 supprimer]`
  - L2 : `[tag-fam ×] [tag-fam ×] [+ ajouter famille]`
- Tap `[+]` sur un item → left column se met en mode palette ; tap famille = ajoute le tag
- En bas col gauche : `[+ Nouvelle famille]` (MX seulement)
- En bas col droite : `[+ Nouveau groove/pattern]`
- Tap item L1 ne sélectionne plus (éviter accidents)

**État "réordonner" (toggle ↕, exclusif avec gérer)**
- Left : collapse/dim
- Right : items du filtre actif uniquement, pleine largeur, avec poignée ≡
- Drag-drop pour réordonner → appel `sbPushSchoolOrder()` au drop

### Règles TX/MX
- MX : rename/delete/tag → publish direct (buildPublishSection)
- TX : rename → `_pendingRename` ; tag → section Tags ; delete → draft cancel
- Création item : ouvre la save-sheet existante

### Ce qui est supprimé
- Bouton `≡` dans `buildGrooveSection` et dans `buildLayers`
- `openLibPanelGrooves()`, `openLibPanelPatterns()` et leurs HTML/CSS
- `#lib-panel-grooves`, `#lib-panel-patterns`, overlays associés
- Listeners close associés, recherche patterns/grooves
- Pas de batch delete (supprimé par décision design)

### Ce qui est conservé
- `#lib-panel-bands` (sons — refonte future)
- `#lib-panel-encyclo` (refonte future)
- `#lib-panel-metro` (refonte future)
- Toutes les fonctions `sbPushSchoolOrder`, `markItemDirty`, `buildPublishSection` — inchangées

### CSS à ajouter (noms suggérés)
- `.pm-mode-btn` — boutons ✎ ↕ dans le header modal
- `.pm-item.pm-manage` — item en mode gérer (flex-column, gap)
- `.pm-item-name-row` — ligne nom + 🗑
- `.pm-item-tags` — ligne chips famille
- `.pm-tag-chip` — chip famille (fond coloré, × pour supprimer)
- `.pm-tag-add` — bouton + ajouter famille
- `.pm-drag-handle` — poignée ≡ réordonner
- `.pm-fam-btn.palette` — famille en attente de sélection (highlight)

## Résolu (session 2026-05-01)
- ✅ **Recherche temps réel** — champ search dans panels Patterns/Grooves/Bands (filtre par nom)
- ✅ **Export MIDI** — modal note+canal par couche, tempo, signature ; SMF Type 0, 96 PPQ (menu `···`)
- ✅ **Ordre familles MX** — `sbPushSchoolFamOrder()` après drag-drop ; fetch trié `ordre.asc`
- ✅ **Mute/unmute couches** — tap court btn-vol bascule toutes les couches groove
- ✅ **Subdivision métro indépendante** — `stepSec = (60/spm)×spb/sub` ; patterns non affectés
- ✅ **Correctif critique attachEvents** — modal MIDI déplacé avant `<script>` (null crash fixé)

## Résolu (session 2026-04-28)
- ✅ **G0** — `initAuth()` invalide `authSession` si `authProfile` null
- ✅ **G8** — Ordre patterns/grooves persisté via `sbPushSchoolOrder()` après drag-drop
- ✅ **GAP_FAM_RENAME_TX** — Renommage TX soumis via `_pendingRename` + section "Tags familles"

## Futur chantier — Metro comme pattern (à valider avec Lamberio)

**Concept :** Remplacer les signatures codées en dur par des presets de métronome éditables,
où les coups du métronome sont encodés comme un pattern (comme les patterns de grooves).

**Motivation :** Les signatures asymétriques (7/8, 11/8…) ont des regroupements variables
(2+2+3, 3+2+2, 2+3+2…) non représentables avec l'architecture actuelle (séparateur fixe toutes
les N croches). Un preset permettrait d'encoder exactement où tombent les accents, les temps et
les subdivisions.

**Structure envisagée d'un preset metro :**
```
{
  id: '7/8_rachenitsa',
  nom: 'Rachenitsa (3+2+2)',
  totalSteps: 7,          // = beatsPerMeasure si croche = unité
  stepsPerBeat: 1,        // unité interne
  pattern: ['A','p','p','P','p','P','p']
  // A = accent fort (temps 1), P = accent moyen (début de groupe), p = pulse léger
}
```

**Impact :** Refonte de `SIGNATURES`, du scheduler métronome, et de `buildStepsDOM` (séparateurs).
**Prérequis :** Valider le modèle de données avec Lamberio avant tout codage.

## Conventions
- Commentaires en français, code en anglais
- Pas de framework, pas de bibliothèque externe
- Mobile-first (testé sur smartphone)
- Écriture de gros fichiers : utiliser scripts bash/heredoc, jamais le Write tool direct
