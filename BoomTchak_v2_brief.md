# BoomTchak v2 — Brief de développement (référence complète)

> **Nom de l'appli :** BoomTchak *(anciennement BasicRythm puis PoumTchak)*  
> **Version courante :** v2.5.0  
> **Fichier :** `/Users/takadimita/Desktop/PoumTchak/index.html` (~3000 lignes)  
> **Dépôt :** https://github.com/LeSonMusical/BoomTchak  
> **Déployé :** https://lesonmusical.github.io/BoomTchak/  
> **Dev local :** `npx serve /Users/takadimita/Desktop/PoumTchak -p 3000 --no-clipboard`

---

## Contexte projet

BoomTchak est une application web pédagogique pour l'enseignement du rythme.
Conçue par Lamberio, professeur de musique, pour un usage scolaire (relai enseignant→élève).
La v2 est une réécriture from scratch sur une architecture propre depuis la v1.6 (~3700 lignes, architecturalement cassée).

**Mode de collaboration :**
- Lamberio = product owner + designer pédagogique. Il décide de l'architecture et du design.
- Claude implémente. Les questions architecturales importantes sont soumises AVANT le code.
- Lamberio a aussi besoin d'un regard critique constructif.
- Claude doit être aussi force de proposition même si cela va à l'encontre de certaines consignes.
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
- Une famille est un ensemble de motifs regroupés par style (afro-cubain, arabe-andalou…), type (binaire, euclidien, impair), fonction (clave, pulse…) ou instrument
- Familles disponibles dans PTK_DEFAULT : `fam_base`, `fam_euclidien`, `fam_afrocubain`, `fam_africain`, `fam_bresilien`, `fam_caraibe`, `fam_flamenco`
- Filtres famille dans les barres de section (chips) — filtre les selects
- Panels ≡ patterns et grooves : section "Gérer les familles" — renommer, supprimer, créer
  - Toutes les familles visibles dans "Gérer les familles" (y compris à 0 item)
  - `rebuildAllFamFilters()` : reconstruit tous les filtres après modification
  - `libDeleteFamille(famId, count)` : supprime une famille + retire de tous patterns ET grooves

---

## Structure de l'interface

```
┌──────────────────────────────────────┐
│  SX/TX  BoomTchak  [Tempo][Sons][⊞][?]│  ← Top bar fixe
├──────────────────────────────────────┤
│  [Band ▼]    (si Sons actif)         │
│  [Groove ▼]                          │  ← zone centrale scrollable
│  Layers (3 couches)                  │
│  [Encyclopédie ▼]                    │
│  [Parcours ▼]  (à venir)             │
├──────────────────────────────────────┤
│  [TX tools] │  ▶/■ Play  │  🤚Jouer  │  ← Bottom bar fixe
└──────────────────────────────────────┘
```

### Modèle unifié de barre de section
```
[Label] [filtre famille chips] [select menu] [💾] [≡] [i] [▶/▼ volet]
```
CSS : `flex-wrap:nowrap; overflow:hidden` — la barre ne déborde jamais.

**Visibilité 💾 / ≡ selon mode :**
| Section | TX | SX |
|---------|----|----|
| Band | 💾 ≡ | 💾 ≡ |
| Groove | 💾 ≡ | 💾 ✓ / ≡ grisé si aucun groove perso |
| Layer | 💾 ≡ | 💾 ✓ / ≡ grisé si aucun pattern perso |
| Encyclo | 💾 ≡ | 💾 seulement (≡ masqué) |

Règle SX : `canOverwrite` protège la sauvegarde des défauts ; les panels ≡ n'affichent que les items `source:'user'`.

### Couleurs des barres
- **Groove** : fond doré `#faf3e0`, bordure gauche `#C8961A`
- **Band** : fond bleu `#eef4f8`, bordure gauche `#4A7FA5`
- **Encyclo** : fond gris `#f5f4f0`, bordure gauche `#888`
- **Layers** : indent visuel `border-left:2px solid #e0d090` depuis le groove

### Bottom bar (v2.3.5)
- **Play** : bordure et actif `#1a1a18` (neutre sobre) — actif : fond noir + texte blanc
- **Jouer** : bordure et couleur `#1D9E75` (accent vert de l'app), hauteur 44px = Play
- **Volet Jouer (drawer)** : fond `#1a1a18` — réservé à la refonte dark/light mode

---

## Modes TX / SX / MX

- **SX** (défaut) : mode élève
- **TX** : mode enseignant — accès complet édition + sauvegarde + création de contenu pédagogique (parcours, étapes, consignes)
- **MX** *(v3)* : mode Master — droits supplémentaires : édition contenu encyclopédique global + gestion des familles de parcours
- Bascule : bouton `SX/TX` top bar gauche + raccourci `Tab`
- URL `?mode=tx` démarre en TX
- En TX : boutons 💾 + ≡ visibles sur toutes les sections
- En SX : 💾 toujours visible (protection par `canOverwrite`) ; ≡ visible mais grisé si aucun item perso pour Groove/Layer, masqué pour Encyclo
- Panels ≡ en SX : liste filtrée sur `source:'user'` uniquement (force `__perso__`)
- Step editing : disponible en SX (canEdit retiré) — `canOverwrite` protège la surcharge des défauts

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
  const needed = n * (sw + 2); // largeur totale avec gaps
  const shouldWrap = needed > avail;
  if(shouldWrap !== state[li].wrapped) buildStepsDOM(li, shouldWrap);
}
```

⚠️ **Bug historique corrigé en v2.2.4** : utiliser `outer.parentElement.clientWidth - 8` sans le gap `2px` produisait des wraps CSS naturels aberrants.

### Point de césure
```js
function halfAt(len){ if(len<=4) return null; return Math.ceil(len/2); }
```
- 8 steps → 4+4 / 12 steps → 6+6 / 16 steps → 8+8

---

## Encyclopédie

- Const `ENCYCLO` : dictionnaire de référence (chapo + bullets) — ne jamais modifier
- Const `ENCYCLO_MISC` : tableau des entrées "Misc" (catégorie M) — ordre du select
  ```js
  [{id:'poumtchak',nom:'★ BoomTchak'},{id:'misc_groove',nom:'Groove'},{id:'misc_pattern',nom:'Pattern'},
   {id:'misc_sons',nom:'Sons & instruments'},{id:'misc_notations',nom:'Notations'},
   {id:'misc_tempo',nom:'Tempo'},{id:'misc_transformations',nom:'Transformations'},{id:'misc_familles',nom:'Familles'}]
  ```
- `packCours.encyclo` : copie éditable + entrées vides auto-créées pour tous items
- Structure : `{ key: { chapo: string, bullets: [[titre, texte], ...] } }`
- En TX : textes éditables (`contentEditable='true'`), détaché 💾
- `hasEncycloContent(key)` : retourne `true` si chapo non vide ou bullets.length > 0
- `updateEncycloSelect(key)` : sélectionne automatiquement dans le select encyclo
- Select encyclo : **SX** masque les entrées vides / **TX** affiche tout en gris
- **Catégorie M (Misc)** : case à cocher dans les filtres du panel ≡ encyclo
- **Migration** : entrées `ENCYCLO_MISC` toujours resynchronisées depuis `ENCYCLO` au chargement (contenu géré par l'app, écrase `packCours.encyclo[m.id]`)

### Format des fiches Pattern
- **Chapo** : l'essentiel en 3 phrases
- **Origine** : contexte géographique, culturel, historique
- **Écritures** : notations et représentations du pattern
- **Construction** : logique propre, comment le rythme se construit
- **Sensation** : sensation physique et émotion provoquées
- **Utilisation** : usages originels et détournés — contexte stylistique (genre musical), instrumental (quel instrument le joue et comment), musical et culturel
- **Relations** : liens avec d'autres patterns du même groove ou patterns similaires/dérivés
- **Variantes** : variantes du pattern et usages détournés

### Format des fiches Groove
- **Origine** : contexte géographique, culturel, historique
- **Organisation** : relations entre les patterns — comment ils se superposent et s'articulent
- **Sensation** : et en conséquence son utilisation/rôle musical/sociologique
- **Utilisation** : contexte stylistique (et usages détournés)
- **Variantes** : variantes du groove

---

## Panels ≡ (lib-panels)

Trois panels distincts : **patterns** (`lib-panel-patterns`), **grooves** (`lib-panel-grooves`), **encyclopédie** (`lib-panel-encyclo`).

Structure commune :
```
Header titre + filtre famille (select)
Liste des items (drag, rename, familles, delete)
Section "Gérer les familles" (rename inline, count, ×)
Section "Ajouter une famille" (input + btn)
```

Panel Encyclopédie : 3 filtres cumulatifs :
1. Filtre famille (select en header)
2. Cases à cocher G/P (grooves / patterns)
3. Toggle Tous / Remplis / Vides

### Actions par item
- `⠿` drag pour réordonner
- Clic nom → edit inline (Enter/Escape)
- Chips famille → add/remove famille sur item
- `×` supprimer (avec count de dépendances)

---

## Moteur audio

Scheduler lookahead : `setTimeout` 25ms / lookahead 100ms (pattern Chris Wilson)
SPM : Steps Par Minute (pas BPM)
3 layers indépendants avec `halfOn` / `doubleOn` par couche.

iOS 18 : `ac.resume()` synchrone dans le handler de clic.
Visualisation : RAF loop séparée du scheduler (`visualLoop()`).

---

## Système sonore

5 couches : Grave / Aigu / Noise / Main gauche / Main droite

### Styles de band actuels (bandId)
| bandId | Grave | Aigu | Noise |
|--------|-------|------|-------|
| `electro` | Kick | Snare | Hi-hat |
| `perc` | Tambour | Clave | Shaker |
| `rock` | Grosse caisse | Caisse claire | Charleston |
| `minimal` | Tom grave | Bell | Noise |

Synthèse Web Audio API pure : Kick, Snare, Clave, Hi-hat, Shaker, Bell, Conga, Bongo, Triangle, Strum, Clap.
Band change : ne déclenche PAS de dirty sur le groove (intentionnel depuis v2.2.1).

### Section Band (à venir — v2 suite)
Un *band* est un ensemble de couches d'instrument/sons superposés.
Chaque instrument appartient à une famille d'instrument :
- Actuelles : Low, High, Noise
- À terme : Bass, Pad-Harm, Key-Arp, Lead-Mel, PercLow, PercHigh, PercNoise

Chaque instrument aura 3 paramètres réglables :
1. Durée/enveloppe dynamique
2. Hauteur/timbre (Pitch, filtre et env de filtre)
3. Volume

Un menu de preset d'instrument sera disponible.

---

## Modes visuels (circulaires)

### Mode visuel actuel — *vitesse-step*
Basé sur la **vitesse du pas** : 1 tour = 1 cycle de pattern. 
Un pattern de 3 steps tourne deux fois plus vite qu'un pattern de 6. 
Le tempo est en **steps par minute (SPM)**.

### Mode visuel bis — *vitesse-cycle*
Toutes les aiguilles avancent à la **même vitesse angulaire** : elles font un tour en même temps. 
Chaque cercle se divise différemment selon le nombre de steps du pattern (3 ou 6 divisions). 
Le tempo est en **MCM (tours par minute)**. Référence de cycle = mesure du groove (`vitesse_mult`). Le flash de step suit le scheduler audio.

Ces deux modes sont complémentaires pédagogiquement : l'un montre la densité rythmique, l'autre la durée du cycle.

### Explication pour les non-musiciens

**Mode vitesse-step :** Imagine trois aiguilles qui tournent chacune sur leur cercle à leur propre vitesse. Si un cercle a 8 points et un autre en a 16, l'aiguille du cercle à 8 points tourne deux fois plus vite — elle a moins de points à "visiter" dans le même temps. On voit directement la densité de chaque rythme : plus de points = aiguille plus lente.

**Mode vitesse-cycle :** Cette fois, toutes les aiguilles tournent exactement à la même vitesse — elles font le tour en même temps. 
La différence, c'est le nombre de points sur chaque cercle : 8 points pour l'un, 16 pour l'autre. Quand l'aiguille passe devant un point, un son est joué. 
Ce mode permet de voir directement quels sons tombent simultanément : si deux points de deux cercles différents se trouvent face à l'aiguille au même moment, les deux sons jouent ensemble. 
C'est ce qu'on appelle un polyrythme.

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

## État d'avancement v2.5.0

### ✅ Implémenté

**Infrastructure**
- Modes TX/SX — toggle + URL `?mode=tx`
- Lecture audio 3 couches + scheduler lookahead
- Version affichée top bar
- Renommage BoomTchak (v2.3.5)

**Sections**
- Band, Groove, Layers, Encyclopédie avec barres uniformes
- Boutons 💾 + ≡ avec règles de visibilité SX/TX (voir tableau ci-dessus)
- Filtres famille (chips) dans barres Groove et Layers
- Option "Perso" (fond vert `#ddfff4`, texte `#0F6E56`) dans tous les menus famille

**Dirty state**
- Système unifié `setDirtyUI` : 💾 rouge + `!` + `● modifié Nom` dans select
- Déclencheurs cohérents sur toutes les sections
- Reset dirty sur navigation

**Sauvegarde**
- Popover psp-box shared (patterns + grooves) via `_pspContext`
- Save sheet 2 choix : Écraser / Sauvegarder comme nouveau
- Dialog "pattern partagé" entre grooves
- localStorage `ptk_content_v2`

**Familles (v2.1+)**
- Pool plat partagé patterns + grooves
- Panels ≡ patterns, grooves, encyclo avec gestion des familles
- Toutes les familles visibles dans "Gérer les familles" (v2.3.4)
- `libDeleteFamille` et renommage : propagation immédiate dans tous les selects (v2.3.4)

**Encyclopédie (v2.2+)**
- Texte éditable en TX, détection vrai changement focus/blur
- Entrées auto-créées vides pour tous patterns ET grooves
- Auto-select à chaque changement de groove ou pattern de couche
- Panel ≡ encyclo avec 4 filtres cumulatifs : famille + M/G/P + Tous/Remplis/Vides — v2.3.2 + v2.4.5
- Catégorie Misc (M) : `ENCYCLO_MISC` (8 entrées) + migration always-sync

**Steps (v2.2.4)**
- Wrap conditionnel + césure au milieu + ResizeObserver

**Bottom bar (v2.3.5)**
- Play : sobriété neutre `#1a1a18`, actif fond noir + texte blanc
- Jouer : aligné hauteur 44px avec Play

**Accents (v2.4.x)**
- 3 états : `X` (forte, vol 100%), `x` (faible, vol ~33%), `.` (silence)
- Cycle au clic : `. → X → x → .`
- Steps éditables en SX également (sans restriction `canEdit`)
- Mod panel : `/2 ×2` | `◀ n ▶` (shift compact) | `⇄ ⇅ ⊙` | `🎲 ✨`
- Transformations tenant compte des accents (×2, /2, reverse, invert, shuffle, magic)

**Source badges (v2.4.5)**
- Badge "perso" (vert) et "défaut" (gris) dans les panels ≡ lib
- Classe CSS `.section-perso` sur `layerDiv` et `#groove-bar` selon `source:'user'`

**Mode SX (v2.4.6 → v2.4.8)**
- Panels ≡ en SX forcés sur filtre `__perso__` (ne montrent que les items `source:'user'`)
- ≡ Groove/Pattern grisé si aucun item perso (disabled + opacity 0.25)
- ≡ Encyclo masqué en SX

**Section Band — volet sons (v2.5.0)**
- Volet collapsible par instrument : flèche ▶/▼ + sliders Hauteur + Enveloppe
- `soundPanelOpen` mémorise l'état ouvert/fermé par couche
- Suppression des boutons ≡/💾 redondants dans les lignes individuelles (ils restent dans la barre Band)

---

## Roadmap

### v2 — Suite (ajouts d'édition et de contenu)

- **Section Band** : création avec paramètres sonores par instrument (enveloppe, pitch/filtre, volume), notion d'instruments par famille (Low, High, Noise → Bass, Pad, etc.)
- **Gestion des accents** : entrée manuelle (X x .) et rendu sonore différencié
- **Mode sombre** : thème dark/light (bottom bar drawer déjà préparé)
- **Mode visuel bis** : cercle à vitesse-cycle uniforme (vs vitesse-step actuel)
- **Liens dans les textes** : liens encyclo vers d'autres items
- **Section références** : liens vers des morceaux réels

### v3 — Google Suite pour sync élève/prof

**Objectif :** les profs créent du *contenu* pédagogique, l'élève suit un *parcours*.

**Architecture technique proposée :**
- Google Apps Script (stockage JSON Drive + URL publique)
- `GET /load?id=xxx` → `https://lesonmusical.github.io/BoomTchak/?pack=xxx`
- Plusieurs profs contributeurs à l'encyclopédie globale (contenu MX)

**Nouveaux concepts :**

#### Parcours pédagogiques
Un *parcours* est une succession d'*étapes*. Chaque étape propose une situation pédagogique = *état* visuel de l'appli (quels items sont visibles, invisibles, lockés) + une *proposition* (description, consignes) + éventuellement un *challenge*.

#### Section Parcours (UI)
```
Parcours [<] [Titre du parcours] [💾 TX] [≡ TX] [>]  [n°étape/total]  [voir >]
```
- `<` / `>` : navigation entre étapes
- Volet parcours : liste des étapes ; étape courante surlignée ; étapes grisées = non accessibles directement

#### Section Étape/Proposition (dans le volet Parcours)
```
étape n/p  [Titre étape] [💾 TX] [≡ TX]  [consignes >]
```
- Encart texte : Objectif/consignes
- *(v4)* Encart Challenge : déclencheur d'envoi + évaluation

#### Mode EditVisibility (TX)
En mode TX, la bottom bar gauche expose :
- Bouton **œil** : passe en mode EditVisibility (édite la visibilité pour l'étape courante)
- Bouton **+** : crée une nouvelle étape OU un nouveau parcours

En mode EditVisibility :
- Un bouton **œil** apparaît à gauche de chaque section
- Sur tous les éléments des volets : voile cliquable pour éditer la visibilité
  - Clic court : toggle visible/invisible
  - Clic long sur visible : toggle lock/visible
- Codes couleur : 🟢 vert = visible · 🔴 rouge = invisible · 🟡 orange = locké (visible mais non interactif)

#### Distinction TX / MX
- **TX** : crée du contenu pédagogique (parcours, étapes, consignes, paramètres par étape)
- **MX** : droits supplémentaires — édition contenu encyclopédique global + gestion des familles de parcours

### v4 — Suivi et évaluation

- **Métronome + signature** → grille sur les steps
- **Export MIDI**
- **Notation classique** : visualisation complémentaire sous les steps
- **Mode Record** : évalue si un élève joue en rythme (tolérance par rapport au step)
- **Mode Record Pattern** : crée de nouveaux patterns en jouant (quantize)
- **Mode Send/Eval** : l'élève envoie des données pour suivi et évaluation du parcours
- **Rythmes impairs** : Orient, Maghreb (5/8, 7/8, 9/8…)

---

## Ce qu'on NE fait PAS avant v3/v4

- Mode Visibilité TX (champ JSON `visibilite` présent mais logique absente)
- Parcours/étapes navigation côté SX
- Export MIDI
- Mode multi-utilisateur
- Rythmes impairs
- *(Potentiellement v2 fin)* Mode sombre

---

## Référence v1.6 (pour futur portage)

Fichier v1.6 dans `old/` :
- Moteur audio (`scheduler`, `visualLoop`, `scheduleNote`, `getBeatSec`) — **déjà porté**
- Synthèse sonore (`SOUND_DEFS`) — **déjà portée**
- Visualisation circulaire (`visualLoopCircle`, `resizeCanvas`) — **à porter**
- Mode Visibilité — **endormi**
- Parcours/étapes — **à porter (v3)**
