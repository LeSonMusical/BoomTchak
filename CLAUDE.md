# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~8900 lignes), vanilla JS, Supabase.
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
Une modification de tag famille est un phénomène distinct d'une modification de contenu. Les deux ne se mélangent pas dans les panneaux Soumettre/Publier.

**Règle 5 — Approuver = approuver ET publier**
Le verbe "Publier" est réservé aux modifications MX. Pour TX, le verbe est "Approuver". Approuver une modification TX = approbation + publication simultanées.

### Conformité par item (post v3.7.0)

| Item | TX Create | TX Update | TX Delete | MX Create | MX Update | MX Delete |
|---|---|---|---|---|---|---|
| Pattern | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Groove | ✅ | ✅ ↺ Renvoyer | ✅ draft cancel | ✅ publish | ✅ publish | ✅ pendingDel |
| Encyclopédie | ✅ | ✅ ↺ Renvoyer | ❌ GAP | ✅ publish | ✅ publish | ❌ GAP |
| Famille école | n/a | ✅ _pendingRename→push | n/a | ✅ localDirty→publish | ✅ localDirty→publish | ✅ pendingDel |
| Famille teacher | ✅ auto-push item | ✅ _pendingRename→push | ✅ local | n/a | n/a | n/a |
| Tag famille | ✅ section Tags | ✅ section Tags | n/a | ✅ section Tags | ✅ section Tags | n/a |
| Metro preset | ✅ via modal sig ✎ | ✅ via modal sig ✎ | ✅ via modal sig ✎ | ✅ publish | ✅ publish | ✅ direct |
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
- `index.html` — application complète (~8900 lignes)
- `BoomTchak_Explain.md` — référence complète (pédagogie + UX + technique + roadmap)
- `BoomTchak_v3_bible.md` — référence technique v3 (DB, RLS, workflows TX/MX)
- `supabase/schema.sql` — schéma Supabase (inclut toutes les migrations jusqu'à v3.7.0)
- `supabase/seed_school_pool.sql` — données initiales école

## Version courante
**v3.8.8** (session 2026-05-02)

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.8.8 | Fix familles métro au démarrage sans connexion : `rebuildMetroPresets()` dans `loadFromStorage()` |
| v3.8.7 | `attachSwipe()` générique sur tous les boutons preset (groove/pattern/band/son) ; vol section bar 1 ligne ; fix `getFams()` fallback famille |
| v3.8.6 | Swipe sur `sig-sel-btn` : navigation preset suivant/précédent avec `_navigateMetroPreset()` |
| v3.8.5 | Nom latin en couleur accent ; `#btn-tempo` muté `opacity:.45`, `active+muté` = dim lilas |
| v3.8.4 | 💾 métro = `btn-sec-save` ; vol slider `flex:1` section bar ; nom tempo centré au-dessus slider |
| v3.8.3 | Correction layout : slider `#bpm` + battue/BPM dans volet (pas section bar) |
| v3.8.2 | Section bar : select battue (♪♩♩.𝅗𝅥) + input BPM ressenti ; vol déplacé section bar ; suppression slider miroir |
| v3.8.1 | `felBeatSteps` + battue éditable ; rescale métronome au changement tempo |
| v3.7.0 | Familles métronome dynamiques : `metro_familles` DB, `familles_ids`+`ordre` sur `metro_presets` |

## Tâches prioritaires (prochaine session)

### Chantier principal : openPresetModal pour Band/Son et Encyclopédie
Appliquer le même design que `openPresetModal` (modal unifié gérer/réordonner/palette) aux volets band/son et encyclopédie.

**À clarifier avec Lamberio en début de session :**
- Quelle est la "petite différence" pour ces deux volets ?
  - Band : les sons (`SOUND_DEFS`) sont prédéfinis (JS hardcoded), pas en DB — le CRUD est-il limité à la gestion des familles + renommage/réordonner uniquement ?
  - Encyclopédie : pas de "familles" au sens groove/pattern. Les items encyclo sont indexés par ID de groove/pattern. La colonne gauche serait quoi (catégories ?) ?

**Volet Band/Son** (actuellement `#lib-panel-bands`) :
- `openPresetModal({type:'band'})` existe déjà pour la sélection
- Manquent les modes gérer/réordonner intégrés au modal
- Sons individuels : `openPresetModal({type:'sound'})` pour la sélection, swipe déjà en place

**Volet Encyclopédie** (actuellement `#lib-panel-encyclo`) :
- Structure différente : contenu textuel (chapo + bullets) par item
- Pas de familles taggables au sens strict
- La "petite différence" à valider

### Autres chantiers en attente
1. **G1 Fork item école** — TX modifie un item école → copie automatique en source:'teacher'
2. **G7 Raison de refus** — MX saisit un message lors du rejet, TX le voit dans le toast

## Résolu (session 2026-05-02 — amélioration section métronome)
- ✅ **Suppression lib-panel-metro** — remplacé par modal sig
- ✅ **Bug tempo en lecture** — rescale `metroNextBeatTime` proportionnel lors du changement slider
- ✅ **felBeatSteps** — paramètre "battue" éditable par preset (♪♩♩.𝅗𝅥), persisté en DB
- ✅ **Section bar métro** — select battue + input BPM + vol slider (monochrome, même hauteur)
- ✅ **Volet métro** — slider #bpm avec −/+, nom latin centré, battue à droite
- ✅ **Swipe universel** — `attachSwipe()` sur groove/pattern/band/son/sig
- ✅ **Familles métro hors connexion** — `rebuildMetroPresets()` dans `loadFromStorage()`

## Résolu (session 2026-05-01)
- ✅ **Recherche temps réel** — champ search dans panels Patterns/Grooves/Bands
- ✅ **Export MIDI** — modal note+canal par couche, tempo, signature ; SMF Type 0, 96 PPQ
- ✅ **Ordre familles MX** — `sbPushSchoolFamOrder()` après drag-drop
- ✅ **Mute/unmute couches** — tap court btn-vol bascule toutes les couches groove
- ✅ **Subdivision métro indépendante** — `stepSec = (60/spm)×spb/sub`
- ✅ **Mode gérer/réordonner openPresetModal** — groove/pattern : rename, delete, tag, drag-reorder

## Résolu (session 2026-04-28)
- ✅ **G0** — `initAuth()` invalide `authSession` si `authProfile` null
- ✅ **G8** — Ordre patterns/grooves persisté via `sbPushSchoolOrder()` après drag-drop
- ✅ **GAP_FAM_RENAME_TX** — Renommage TX soumis via `_pendingRename` + section "Tags familles"

## Architecture `openPresetModal` (état v3.8.x)

```
openPresetModal(cfg)
  cfg.type : 'groove' | 'pattern' | 'sig' | 'sound' | 'band'

  États communs à groove/pattern/sig :
    manageMode  (✎) : rename/delete items + CRUD tags famille
    reorderMode (☰) : drag-drop items et familles, persistance DB
    paletteMode : colonne gauche = sélecteur de famille à tagger

  Helper swipe (global) :
    attachSwipe(el, getList, getCurrentId, onSelect)
    → swipe gauche = suivant, droite = précédent (seuil 30px)
    → utilisé sur : sig-sel-btn, groove-preset-btn, preset-btn-{id}, band-preset-btn, soundPresetBtn

  Fonctions internes :
    getFams()           → familles filtrées selon type (fallback .famille si familles_ids absent)
    getFilteredItems()  → items filtrés (famFilter + searchQuery)
    pmNewFamille()      → crée famille
    pmDeleteFam(fam)    → supprime famille + détache les tags
    pmDropFam(src,tgt)  → réordonne familles + persist DB
    pmDrop(src,tgt)     → réordonne items + persist DB
    pmAddTag / pmRemoveTag
    pmStartRename / _pmStartRenameMetroFam

  Persistance ordre :
    sbPushSchoolFamOrder()      → familles école (patterns/grooves)
    sbPushSchoolMetroFamOrder() → familles métronome
    sbPushSchoolOrder(type)     → items patterns/grooves
    sbPushSchoolMetroOrder()    → items metro_presets
```

## Conventions
- Commentaires en français, code en anglais
- Pas de framework, pas de bibliothèque externe
- Mobile-first (testé sur smartphone)
- Écriture de gros fichiers : utiliser scripts bash/heredoc, jamais le Write tool direct
