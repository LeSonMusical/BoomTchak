# PoumTchak v2 — Brief de développement (référence complète)

> **Version courante :** v2.2.4 — commit `6f1f696`  
> **Fichier :** `/Users/takadimita/Desktop/PoumTchak/index.html` (~2900 lignes)  
> **Dépôt :** https://github.com/LeSonMusical/BoomTchak  
> **Déployé :** https://lesonmusical.github.io/BoomTchak/  
> **Dev local :** `ruby -run -e httpd /Users/takadimita/Desktop/PoumTchak -p 3000`  
> *(Python bloqué par macOS PermissionError sur `os.getcwd()`)*

---

## Contexte projet

PoumTchak est une application web pédagogique pour l'enseignement du rythme.
Conçue par Lamberio, professeur de musique, pour un usage scolaire (relai enseignant→élève).
La v2 est une réécriture from scratch sur une architecture propre depuis la v1.6 (~3700 lignes, architecturalement cassée).

**Mode de collaboration :**
- Lamberio = product owner + designer pédagogique. Il décide de l'architecture et du design.
- Claude implémente. Les questions architecturales importantes sont soumises AVANT le code.
- Lamberio a aussi besoin d'un regard critique constructif. 
- Claude doit être aussi force de proposition meme si cela va à l'encontre de certains consignes
- Langue : français. Variables/fonctions : camelCase anglais.

---

## Contraintes absolues

- **Fichier unique** : `index.html` — HTML + CSS + JS inline, zéro dépendance externe
- **Vanilla JS** : pas de framework, pas de bibliothèque
- **Web Audio API** native uniquement pour l'audio
- **Mobile-first** : testé prioritairement sur smartphone
- **Déploiement** : GitHub Pages (statique pur)
- **Future-proof** : architecture prête pour portage Capacitor (iOS/Android) ou Electron

---

## Architecture JS cible

```
index.html
│
└── <script>
    ├── MODULE DATA       Source de vérité unique (jamais le DOM)
    │   ├── CONTENT       patterns, grooves, familles, encyclo (données par défaut)
    │   └── packCours     état courant du cours (mutable, cloné depuis PTK_DEFAULT)
    │
    ├── MODULE AUDIO      Moteur scheduler (Chris Wilson lookahead)
    │
    ├── MODULE RENDER     DOM piloté par DATA, jamais l'inverse
    │
    ├── MODULE TX         Mode enseignant (édition, sauvegarde)
    │
    └── INIT              Bootstrap au chargement
```

**Règle fondamentale** : le DOM est un affichage, jamais une base de données.

---

## Format JSON — Source de vérité

```json
{
  "meta": { "titre": "Mon cours", "auteur": "", "version": "2.0", "date": "" },

  "familles": [
    { "id": "fam_afrocubain", "nom": "Afro-cubain" }
  ],

  "patterns": [
    {
      "id": "tres",
      "nom": "Tresillo",
      "familles": ["fam_euclidien", "fam_afrocubain"],
      "sequence": "X..X..X.",
      "pas": 8,
      "unite_temps": "1/8",
      "pas_par_mesure": 8,
      "encyclo_ref": "tres",
      "source": "default"
    }
  ],

  "grooves": [
    {
      "id": "salsa32",
      "nom": "Salsa 3:2",
      "familles": ["fam_afrocubain"],
      "band_defaut": "perc",
      "tempo": { "min": 80, "max": 360, "defaut": 200 },
      "vitesse_mult": 2,
      "layers": [
        { "id": "grave", "patternId": "tres",    "mute": false, "shift": 0, "halfOn": false, "doubleOn": false },
        { "id": "aigu",  "patternId": "son32",   "mute": false, "shift": 0, "halfOn": false, "doubleOn": false },
        { "id": "noise", "patternId": "cascara", "mute": false, "shift": 0, "halfOn": false, "doubleOn": false }
      ]
    }
  ],

  "encyclo": {
    "tres": {
      "chapo": "Texte chapeau...",
      "bullets": [["Titre", "Texte"], ["Titre2", "Texte2"]]
    },
    "salsa32": { "chapo": "", "bullets": [] }
  },

  "menus": {
    "groove": { "ordre": [], "caches": [] },
    "encyclo": { "ordre": [], "caches": [] }
  },

  "parcours": {
    "etapes": [
      {
        "id": "etape_01",
        "titre": "Découverte",
        "consigne": "",
        "etat_appli": {
          "grooveId": "salsa32",
          "bandId": "perc",
          "tempo": { "min": 60, "max": 120, "defaut": 80 },
          "sections": { "band": "ferme", "encyclo": "ouvert" }
        },
        "visibilite": {}
      }
    ]
  }
}
```

### Règles du format
- `sequence` : `X` (fort) / `x` (faible) / `.` (silence)
- `source` : `'default'` (fourni par l'app) ou `'user'` (créé par l'enseignant)
- `encyclo_ref` sur les patterns : clé vers `packCours.encyclo`. Si absent, la clé est `pattern.id`
- **Clé encyclopédie** : toujours `p.encyclo_ref || p.id` pour un pattern, `g.id` pour un groove
- Toutes les entrées encyclo (patterns ET grooves) sont **auto-créées vides** au chargement si absentes
- `halfOn`/`doubleOn` par layer : vitesse relative de la couche (×0.5 / ×2)
- `vitesse_mult` sur groove : multiplicateur global tempo
- `visibilite` : champ présent mais **ENDORMI en v2** (logique absente)

---

## Familles — système unifié

- `packCours.familles` = pool plat partagé entre patterns ET grooves (ex. `fam_afrocubain`)
- Chaque pattern/groove a `familles: []` (tableau d'ids)
- Familles disponibles dans PTK_DEFAULT : `fam_base`, `fam_euclidien`, `fam_afrocubain`, `fam_africain`, `fam_bresilien`, `fam_caraibe`, `fam_flamenco`
- Filtres famille dans les barres de section (chips) — filtre les selects
- Panels ≡ patterns et grooves : section "Gérer les familles" — renommer, supprimer, créer
  - Familles avec 0 items sont masquées dans les panels
  - `rebuildAllFamFilters()` : reconstruit tous les filtres après modification
  - `libDeleteFamille(famId, count)` : supprime une famille + retire de tous patterns ET grooves

---

## Structure de l'interface

```
┌──────────────────────────────────────┐
│  SX/TX  PoumTchak  [Tempo][Sons][⊞][?]│  ← Top bar fixe
├──────────────────────────────────────┤
│  [Band ▼]    (si Sons actif)         │
│  [Groove ▼]                          │  ← zone centrale scrollable
│  Layers (3 couches)                  │
│  [Encyclopédie ▼]                    │
├──────────────────────────────────────┤
│            │  ▶/■ Play  │  🤚Jouer   │  ← Bottom bar fixe
└──────────────────────────────────────┘
```

### Modèle unifié de barre de section
```
[Label] [filtre famille chips] [select menu] [💾] [≡ TX only] [i] [▶/▼ volet]
```
CSS : `flex-wrap:nowrap; overflow:hidden` — la barre ne déborde jamais.

### Couleurs des barres
- **Groove** : fond doré `#faf3e0`, bordure gauche `#C8961A`
- **Band** : fond bleu `#eef4f8`, bordure gauche `#4A7FA5`
- **Encyclo** : fond gris `#f5f4f0`, bordure gauche `#888`
- **Layers** : indent visuel `border-left:2px solid #e0d090` depuis le groove

---

## Modes TX / SX

- **SX** (défaut) : mode élève
- **TX** : mode enseignant — accès complet édition + sauvegarde
- Bascule : bouton `SX/TX` top bar gauche + raccourci `Tab`
- URL `?mode=tx` démarre en TX
- En TX : boutons 💾 + ≡ visibles sur chaque section

---

## Système dirty state — UNIFIÉ

Fonction centrale : `setDirtyUI(selectId, btnId, isDirty)`
- Bouton 💾 → classe `.dirty` → CSS rouge + `!` via `::after`
- Option courante du select → préfixe `"● modifié "` + couleur rouge
- **Ne jamais créer de variante ad hoc** : toujours déléguer à cette fonction

Les 3 wrappers :
```js
setLayerDirty(li, isDirty)       // → sel-{layerId} + save-btn-layer-{li}
updateGrooveSaveBtn()            // → groove-select + save-btn-groove
updateEncycloSaveBtn()           // → encyclo-select + save-btn-encyclo
```

**Déclencheurs dirty :**
| Action | Effet |
|--------|-------|
| Clic sur un step | `setLayerDirty(li, true)` |
| Changement pattern select (TX) | `grooveDirty=true` |
| Mute toggle | `grooveDirty=true` |
| Texte encyclo modifié (blur ≠ focus) | `encycloDir=true` |

**Reset dirty :**
| Action | Reset |
|--------|-------|
| `applyGroove()` (changement groove) | `grooveDirty=false` + toutes couches `false` |
| Layer pattern select change | `setLayerDirty(li, false)` |
| Encyclo select change | `encycloDir=false` |

**Détection changement contenteditable :** sauvegarder valeur au `focus` (`element.dataset.orig`), comparer au `blur`.

---

## Système de sauvegarde (TX)

### Popover psp-box (patterns et grooves)

Variable de contexte : `_pspContext = 'pattern' | 'groove'`

- **① Écraser [nom]** → `doOverwrite()` → si pattern partagé entre grooves → `showPatternShareDialog()`
  - Dialog : `'all'` (écraser partout) / `'new'` (rouvrir en mode nouveau) / `'cancel'`
- **② Sauvegarder comme nouveau** → champ nom + select famille → `doSaveNew()`

`saveGroove()` persiste : `patternId`, `mute`, `halfOn`, `doubleOn` par couche.

### localStorage
- Clé `ptk_content_v2` : contenu courant
- Chargement au démarrage dans `loadFromStorage()`

### Migrations au chargement
Dans `loadFromStorage()`, après chargement :
1. `packCours.familles` créé si absent
2. `familles:[]` garanti sur chaque pattern et groove
3. `packCours.encyclo` initialisé depuis `ENCYCLO` si absent
4. Entrées encyclo vides créées pour tous grooves (`g.id`) et tous patterns (`p.encyclo_ref || p.id`) si absentes

---

## Steps — affichage et wrap

### Layout
- `.layer-steps` : `display:flex; flex-wrap:wrap; gap:2px`
- `.step` : `width:22px; height:22px` (mobile <600px : `width:20px; height:20px`)
- `const STEP_W = 22` — référence JS

### Wrap conditionnel
```js
function checkWrap(li){
  const outer = document.getElementById('steps-'+LAYERS[li].id); if(!outer) return;
  const avail = outer.clientWidth; // largeur RÉELLE du conteneur de steps
  if(!avail) return;
  const n = state[li].pattern.length;
  const sw = window.innerWidth < 600 ? 20 : 22; // step width selon breakpoint CSS
  const needed = n * (sw + 2); // largeur totale avec gaps (légère marge de sécurité)
  const shouldWrap = needed > avail;
  if(shouldWrap !== state[li].wrapped) buildStepsDOM(li, shouldWrap);
}
```

⚠️ **Bug historique corrigé en v2.2.4** : utiliser `outer.parentElement.clientWidth - 8` sans le gap `2px` produisait des wraps CSS naturels aberrants (10+2 au lieu de 6+6 pour 12 steps).

### Point de césure
```js
function halfAt(len){ if(len<=4) return null; return Math.ceil(len/2); }
```
- 8 steps → 4+4 / 12 steps → 6+6 / 16 steps → 8+8

### Breakpoint DOM
`buildStepsDOM(li, wrap)` insère un div `flex-basis:100%` à l'index `halfAt(n)` pour forcer le retour à la ligne.

### ResizeObserver
`attachLayerObserver(li)` attache un observer sur `outer.parentElement`. Disconnecté dans `buildLayers()` via `layerObservers.forEach(o=>o.disconnect())`.

---

## Encyclopédie

- Const `ENCYCLO` : dictionnaire de référence (chapo + bullets) — ne jamais modifier
- `packCours.encyclo` : copie éditable + entrées vides auto-créées pour tous items
- Structure : `{ key: { chapo: string, bullets: [[titre, texte], ...] } }`
- En TX : textes éditables (`contentEditable='true'`), detached 💾
- `hasEncycloContent(key)` : retourne `true` si chapo non vide ou bullets.length > 0
- `updateEncycloSelect(key)` : sélectionne automatiquement dans le select encyclo
  - Appelé depuis `applyGroove(grooveId)`, changement pattern layer, et `start()`
- Select encyclo :
  - **En SX** : masque les entrées vides (seulement `hasEncycloContent`)
  - **En TX** : affiche tout, entrées vides en gris
- `buildEncycloSection()` reconstruit tout le select (appelé aussi depuis `setMode()`)

---

## Panels ≡ (lib-panels)

Deux panels distincts : **patterns** (`lib-panel-patterns`) et **grooves** (`lib-panel-grooves`).

Structure commune :
```
Header titre
Filtre: [Tous | G | P] + filtre famille (chips)
Liste des items (drag, rename, familles, delete)
Section "Gérer les familles" (rename inline, count, ×)
Section "Ajouter une famille" (input + btn)
```

### Actions par item
- `≡` drag pour réordonner
- Clic nom → edit inline (Enter/Escape)
- Chips famille → add/remove famille sur item
- `×` supprimer (avec count de dépendances)

---

## Moteur audio

Scheduler lookahead : `setTimeout` 25ms / lookahead 100ms (pattern Chris Wilson)
SPM : Steps Par Minute (pas BPM)
3 layers indépendants avec `halfOn` / `doubleOn` par couche.

Variables audio clés :
```js
let playing = false;
let ac = null;
let globalSpeedMult = 1;
let pendingGlobalMult = 1;
let schedTimerID = null;
let visualRafID = null;
const LOOKAHEAD = 0.1;
const SCHED_MS = 25;
```

iOS 18 : `ac.resume()` synchrone dans le handler de clic.
Visualisation : RAF loop séparée du scheduler (`visualLoop()`).

---

## Système sonore

5 couches : Grave / Aigu / Noise / Main gauche / Main droite

### Styles de band (bandId)
| bandId | Grave | Aigu | Noise |
|--------|-------|------|-------|
| `electro` | Kick | Snare | Hi-hat |
| `perc` | Tambour | Clave | Shaker |
| `rock` | Grosse caisse | Caisse claire | Charleston |
| `minimal` | Tom grave | Bell | Noise |

Synthèse Web Audio API pure : Kick, Snare, Clave, Hi-hat, Shaker, Bell, Conga, Bongo, Triangle, Strum, Clap.
Band change : ne déclenche PAS de dirty sur le groove (intentionnel depuis v2.2.1).

---

## Dictionnaire de patterns (PTK_DEFAULT.patterns)

| id | nom | pas | famille |
|----|-----|-----|---------|
| `pulse1` | Pulse | 1 | base |
| `bin2` | Bin (1:2) | 2 | base |
| `ter3` | Ter (1:3) | 3 | base |
| `fl4` | Four on the Floor | 8 (1/8) | base |
| `offbeat` | Off Beat (2,4) | 8 (1/8) | base |
| `pulse4` | Pulse (4:4) | 4 | base |
| `sync4` | Double Up (2:4) | 4 | base |
| `silence` | Silence | 4 | base |
| `tres` | Tresillo | 8 (1/8) | euclidien, afrocubain |
| `cinq` | Cinquillo | 8 (1/8) | afrocubain |
| `hab` | Habanera | 8 (1/8) | afrocubain |
| `afoxe` | Afoxê / Bolero | 8 (1/8) | afrocubain, africain |
| `reggae` | Clave Reggae | 8 (1/8) | caraibe |
| `son32` | Son 3:2 | 16 (1/16) | afrocubain |
| `son` | Son (2:3) | 16 (1/16) | afrocubain |
| `rum32` | Rumba 3:2 | 16 (1/16) | afrocubain |
| `shiko` | Shiko | 16 (1/16) | africain |
| `bossa` | Bossa Nova | 16 (1/16) | brésilien |
| `gahu` | Gahu | 16 (1/16) | africain |
| `souk` | Soukous | 16 (1/16) | africain |
| `samba` | Samba | 16 (1/16) | brésilien |
| `cascara` | Cascara 3:2 | 16 (1/16) | afrocubain |
| `tumbao` | Tumbao | 16 (1/16) | afrocubain |
| `fume` | Fume-fume | 12 (1/12) | africain |
| `bembe` | Bembé | 12 (1/12) | africain |
| `solea` | Soleá | 12 (1/12) | flamenco |

---

## Grooves par défaut (PTK_DEFAULT.grooves)

| id | nom | familles | band_defaut | vitesse_mult |
|----|-----|----------|-------------|--------------|
| `salsa32` | Salsa 3:2 | afrocubain | perc | 2 |
| `bossanova` | Bossa Nova | brésilien | minimal | 1 |
| `techno` | Techno | — | electro | 1 |
| `reggae` | Reggae | caraibe | rock | 1 |
| `dancehall` | Dancehall | caraibe | perc | 2 |

---

## Encyclopédie — entrées ENCYCLO (const)

Toutes ont `{ chapo, bullets[[titre,texte],...] }` :
`tres`, `cinq`, `hab`, `afoxe`, `reggae` (clave), `son32`, `son`, `rum32`, `shiko`, `bossa`, `gahu`, `souk`, `samba`, `cascara`, `tumbao`, `fume`, `bembe`, `solea`, `fl4`, `offbeat`

---

## Conventions de code

- Commentaires en français
- Noms variables/fonctions en camelCase anglais
- Modules séparés : `// ═══ MODULE NOM ═══`
- `let` et `const` uniquement (pas de `var`)
- Pas d'`innerHTML` pour construire des éléments complexes
- Fonctions pures quand possible
- **Version** : `MAJEUR.MINEUR.PATCH`, bumpée à chaque commit, affichée dans top bar (`<span class="app-version">`)

---

## État d'avancement v2.2.4

### ✅ Implémenté

**Infrastructure**
- Modes TX/SX — toggle + URL `?mode=tx`
- Lecture audio 3 couches + scheduler lookahead
- Version affichée top bar

**Sections**
- Band, Groove, Layers, Encyclopédie avec barres uniformes
- Boutons 💾 (TX+SX selon section) et ≡ (TX only) par section
- Filtres famille (chips) dans barres Groove et Layers

**Dirty state**
- Système unifié `setDirtyUI` : 💾 rouge + `!` + `● modifié Nom` dans select
- Déclencheurs cohérents sur toutes les sections
- Reset dirty sur navigation (changement de sélection)

**Sauvegarde**
- Popover psp-box shared (patterns + grooves) via `_pspContext`
- Save sheet 2 choix : Écraser / Sauvegarder comme nouveau
- Dialog "pattern partagé" entre grooves
- `saveGroove()` : sync complet (patternId + mute + halfOn + doubleOn par couche)
- localStorage `ptk_content_v2`

**Familles (v2.1+)**
- Familles partagées patterns + grooves (pool plat)
- Multi-appartenance
- Panel ≡ patterns : liste items, drag, rename, familles, delete, gérer familles
- Panel ≡ grooves : idem
- `libDeleteFamille` : nettoie patterns ET grooves
- Familles vides masquées dans les panels

**Encyclopédie (v2.2+)**
- Texte éditable en TX (contenteditable), détection vrai changement focus/blur
- Entrées auto-créées vides pour tous patterns ET grooves
- Select inclut TOUS les patterns (pas seulement ceux avec `encyclo_ref`)
- Auto-select à chaque changement de groove ou pattern de couche
- SX : entrées vides masquées / TX : entrées vides grisées

**Steps (v2.2.4)**
- Wrap conditionnel (seulement si pas de place)
- Calcul correct : `outer.clientWidth` + `n*(sw+2)` (inclut gap CSS)
- Césure toujours au milieu : `halfAt(n) = Math.ceil(n/2)`
- ResizeObserver par couche (disconnecté au rebuild)

### 🔜 Prochaines phases

**P2 — ≡ Menu management**
- Rename, reorder, delete, ajout grooves/patterns dans les panels ≡
- Interface actuellement en place mais fonctionnalités incomplètes

**Encyclopédie ≡**
- Édition de structure : ajout/suppression d'entrées depuis le panel lib

**Visualisation circulaire**
- Canvas rotatif synchronisé au playback (code v1.6 à porter)

**P3 — Parcours/étapes**
- Navigation TX (structure JSON prête, UI absente)

**Sync prof→élève**
- Google Apps Script (stockage JSON Drive + URL publique)
- `GET /load?id=xxx` → `https://[github-pages]/?pack=xxx`

---

## Ce qu'on NE fait PAS en v2

- Mode Visibilité TX (endormi — champ JSON `visibilite` présent mais logique absente)
- Parcours/étapes navigation côté SX (P3)
- Export MIDI
- Mode multi-utilisateur
- Mode sombre
- Rythmes sur bases impaires

---

## Référence v1.6 (pour futur portage)

Fichier v1.6 dans `old/` :
- Moteur audio (`scheduler`, `visualLoop`, `scheduleNote`, `getBeatSec`) — **déjà porté**
- Synthèse sonore (`SOUND_DEFS`) — **déjà portée**
- Visualisation circulaire (`visualLoopCircle`, `resizeCanvas`) — **à porter**
- Mode Visibilité — **endormi**
- Parcours/étapes — **à porter (P3)**
