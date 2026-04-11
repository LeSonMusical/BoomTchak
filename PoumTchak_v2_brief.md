# PoumTchak v2.0 — Brief de développement

## Contexte projet

PoumTchak est une application web pédagogique pour l'enseignement du rythme.
Conçue par Lamberio, professeur de musique, pour un usage scolaire (relai enseignant→élève).
La v1.6 existante (~3700 lignes, fichier unique) est une base fonctionnelle mais architecturalement cassée.
La v2.0 est une réécriture from scratch sur une architecture propre.

---

## Contraintes architecturales ABSOLUES

- **Fichier unique** : `index.html` — HTML + CSS + JS inline, zéro dépendance externe
- **Vanilla JS** : pas de framework (React, Vue, etc.), pas de bibliothèque
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
    │   ├── CONTENT       patterns, grooves, familles (données par défaut)
    │   └── packCours     état courant du cours (modifiable par TX)
    │
    ├── MODULE AUDIO      Moteur scheduler (copié depuis v1.6, stable)
    │
    ├── MODULE RENDER     DOM piloté par DATA, jamais l'inverse
    │
    ├── MODULE TX         Mode enseignant (édition, sauvegarde)
    │   └── Visibilité    ENDORMIE pour v2.0 test A
    │
    └── INIT              Bootstrap au chargement
```

**Règle fondamentale** : le DOM est un affichage, jamais une base de données.

---

## Format JSON — Source de vérité (VALIDÉ)

```json
{
  "meta": {
    "titre": "Mon cours",
    "auteur": "",
    "version": "1.0",
    "date": ""
  },
  "familles": [
    { "id": "fam_01", "nom": "Afro-cubain", "description": "..." }
  ],
  "patterns": [
    {
      "id": "clave_3_2",
      "nom": "Clave 3:2",
      "texte": "...",
      "familles": ["fam_01"],
      "sequence": "X..x..X...X.x...",
      "pas": 16,
      "unite_temps": "1/8",
      "pas_par_mesure": 8,
      "shift": 0,
      "tempo": { "min": 160, "max": 220 },
      "references": [
        {
          "artiste": "Irakere",
          "titre": "Bacalao con Pan",
          "timestamp": "0:14",
          "mbid": "",
          "texte": "On entend la clave dès l'intro..."
        }
      ]
    }
  ],
  "grooves": [
    {
      "id": "groove_01",
      "nom": "Clave 3-2 complète",
      "texte": "...",
      "familles": ["fam_01"],
      "band_defaut": "afro_latin",
      "tempo": { "min": 100, "max": 200, "defaut": 120 },
      "references": [],
      "layers": [
        {
          "id": "grave",
          "patternId": "clave_3_2",
          "mute": false,
          "shift": 0,
          "unite_temps": "1/8",
          "pas_par_mesure": 8
        },
        {
          "id": "aigu",
          "patternId": "tresillo",
          "mute": false,
          "shift": 0,
          "unite_temps": "1/8",
          "pas_par_mesure": 8
        },
        {
          "id": "noise",
          "patternId": "pulse_4_4",
          "mute": true,
          "shift": 0,
          "unite_temps": "1/8",
          "pas_par_mesure": 8
        }
      ]
    }
  ],
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
          "grooveId": "groove_01",
          "bandId": "afro_latin",
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
- `sequence` : chaîne de caractères, 3 niveaux — `X` (fort) / `x` (faible) / `.` (silence)
- `shift` au niveau layer surcharge le shift du pattern
- `unite_temps` + `pas_par_mesure` : valeurs moteur audio (pas de chiffrage musical — conversion à faire côté UI)
- Chaque layer peut avoir son propre `unite_temps` → supporte polymétrie et polyrythmie
- `tempo` toujours sous forme `{ min, max, defaut }` — omis si non pertinent
- `visibilite` : map de chemins `"section.sous-section.item"` → `"visible"|"cache"|"gele"` — **champ présent mais ignoré en v2.0**

---

## Structure de l'interface (à conserver depuis v1.6)

```
┌──────────────────────────────────────┐
│  SX/TX  PoumTchak  [Tempo][Sons][⊞][?] │  ← Top bar fixe
├──────────────────────────────────────┤
│  [Étape ▼]   (TX only, endormi v2.0) │
│  [Band ▼]    (si Sons actif)         │  ← zone centrale scrollable
│  [Groove ▼]                          │
│  Layers (3 couches)                  │
│  [Encyclopédie ▼]                    │
├──────────────────────────────────────┤
│  (vide)  │  ▶/■ Play  │  🤚Jouer    │  ← Bottom bar fixe
└──────────────────────────────────────┘
```

### Sections (terme préféré à "volet")
Chaque section a une barre uniforme :
```
[Label] [select menu] [💾] [✏️ TX only] [i] [Section ▶/▼]
```

---

## Modes TX / SX

- **SX** (défaut) : mode élève — interface selon configuration enseignant
- **TX** : mode enseignant — accès complet édition + sauvegarde
- Bascule : bouton `SX/TX` top bar gauche + raccourci `Tab`
- URL `?mode=tx` démarre en TX
- **Mode Visibilité** : ENDORMI en v2.0 (bouton masqué, logique absente)

### Périmètre TX pour test A (priorités)
- **P1** : Sauvegarde/chargement patterns, grooves, textes encyclo
- **P2** : Édition des menus groove et encyclo (ordre, rename, delete, ajout)
- **P3** : Parcours + étapes + visibilité (ENDORMI)

---

## Moteur audio (à copier depuis v1.6, ne pas modifier)

- Scheduler lookahead : `setTimeout` 25ms / lookahead 100ms (pattern Chris Wilson)
- SPM : Steps Par Minute (pas BPM)
- 3 layers indépendants avec timing décalé possible
- Changement de groove : resync au PPMC des longueurs (à implémenter proprement)
- iOS 18 : `ac.resume()` synchrone dans le handler de clic
- Visuel : RAF loop séparée du scheduler audio

### Variables audio clés
```javascript
let playing = false;
let ac = null;
let globalSpeedMult = 1;
let pendingGlobalMult = 1;
let schedTimerID = null;
let visualRafID = null;
const LOOKAHEAD = 0.1;
const SCHED_MS = 25;
```

---

## Système sonore (à copier depuis v1.6)

5 couches : Grave / Aigu / Noise / Main gauche / Main droite

### Styles de band
| Style | Grave | Aigu | Noise |
|-------|-------|------|-------|
| Électro | Kick | Snare | Hi-hat |
| Percussions | Tambour | Clave | Shaker |
| Rock | Grosse caisse | Caisse claire | Charleston |
| Minimaliste | Tom grave | Bell | Noise |

### Synthèse (Web Audio API pure)
Kick, Snare, Clave, Hi-hat, Shaker, Bell, Conga, Bongo, Triangle, Strum, Clap
→ Toutes les fonctions de synthèse sont dans la v1.6, à copier intégralement.

---

## Dictionnaire de patterns (à migrer depuis v1.6 vers JSON)

### Référentiels
- Bin 1:2 — `X.` (2 pas)
- Ter 1:3 — `X..` (3 pas)
- Pulse 4:4 — `Xxxx` (4 pas)

### 4 pas

- - Off Beat (2,4) — `.X.X`
- Double Up (2,4) — `..Xx`
- Takami (3,4) - `XX.X`

### 8 pas (1/8)

- Silence 0,4 — `.....`
- Four on the Floor — `X.X.X.X.`
- Tresillo — `X..X..X.'
- Habanera — `X..xX.X.`
- Cinquillo — `X.XX.X.X`
- Klee Pattern - `..XX.X.`

### 16 pas (1/16)
- Bossa Nova — `X..X..X..X..X...`
- Son Clave 3:2 — `X..X..X...X.X...`
- Son Clave 2:3 — `...X.X...X..X..X`
- Clave Reggae — `X...X..X........`
- Cascara 2:3 — `X.XX.X.XX.X.XX.X`
- Tumbao 2:3 — `..X...X.X.......`

### 12 pas (ternaire)
- Bembé — `X.XX.XX.X.X.`
- Soleá — `X.X..X.X.X..`
- Afoxê — `X..X..X.X...`
- Gahu — `X.X.XX.X.X..`

---

## Encyclopédie (entrées validées — à migrer)

Chaque entrée a : `id`, `nom`, `chapo` (texte court), `corps` (texte long), `exemples` (liste), `pattern_ref` (id pattern associé)

Entrées existantes dans v1.6 :
`_poumtchak`, `tresillo`, `cinquillo`, `habanera`, `clave_reggae`, `bossa_nova`, `gahu`, `shiko`, `fume_fume`, `samba`, `tumbao`, `bembe`, `afoxe`, `bolero`, `off_beat`, `son_3_2`, `cascara`, `solae`

---

## Sauvegarde — Architecture cible

### Phase test A (à implémenter)
```
TX (prof)                      SX (élève)
─────────────────              ──────────────────
Édite le contenu          →    Reçoit URL publique
Clique 💾 Sauvegarder     →    Ouvre l'appli
  ↓                              ↓
Google Apps Script         →    Charge le JSON
(stocke dans Google Drive)      (sans compte requis)
```

### localStorage (intermédiaire)
- Clé `ptk_content_v2` : contenu courant (patterns, grooves)
- Clé `ptk_menus_v2` : configuration menus
- Chargement au démarrage si présent

### Google Apps Script (phase suivante)
- Script déployé comme Web App publique
- `POST /save` → stocke JSON, retourne un `id`
- `GET /load?id=xxx` → retourne le JSON
- L'élève reçoit l'URL : `https://[github-pages]/?pack=xxx`

---

## Conventions de code

- Commentaires en français
- Noms de variables/fonctions en camelCase anglais
- Modules séparés par des blocs commentés `// ═══ MODULE NOM ═══`
- Pas de `var`, uniquement `let` et `const`
- Pas d'`innerHTML` pour construire des éléments complexes (sécurité + lisibilité)
- Fonctions pures quand possible (pas d'effets de bord cachés)
- **Version** : format `MAJEUR.MINEUR.PATCH`, bumpée à chaque commit, affichée dans la top bar (`<span class="app-version">`)

---

## Système de sections — Design unifié

**Règle** : toutes les sections ont exactement le même modèle de barre :
```
[Label] [select menu] [💾 btn-sec-save] [≡ TX only] [i] [▶/▼ volet]
```

**Dirty state unifié** — `setDirtyUI(selectId, btnId, isDirty)` :
- Bouton 💾 → classe `.dirty` → CSS `.btn-sec-save.dirty` (rouge + `!`)
- Option courante du select → suffixe `" ✱"`
- **Ne jamais créer de variante ad hoc** : toujours déléguer à cette fonction

**Déclencheurs dirty (règle générale) :**
- Toute modification du contenu d'une section → `dirty = true`
- Changement de sélection dans un menu → `dirty = false` (état frais)
- Changement de groove → reset dirty groove ET toutes les couches

**Détection de vrai changement (contenteditable) :**
- Sauvegarder la valeur au `focus` (`element.dataset.orig`)
- Comparer au `blur` — ne marquer dirty que si `textContent !== dataset.orig`

---

## État d'avancement (v2.0.6 — session 2)

### ✅ Implémenté
- Modes TX/SX — toggle + URL `?mode=tx`
- Lecture audio 3 couches + scheduler lookahead
- Sections : Band, Groove, Layers, Encyclopédie
- Boutons 💾 et ≡ par section
- Dirty state unifié (`setDirtyUI`) : 💾 rouge + `✱` dans select
- Save sheet 2 choix : ① Écraser / ② Sauvegarder comme nouveau
- Dialog "pattern partagé" entre grooves (option : écraser partout / nouveau)
- Encyclo : texte éditable en TX (contenteditable), détection de vrai changement
- `saveGroove()` : sync complet (patternId + mute + halfOn + doubleOn)
- Version affichée dans la top bar

### 🔜 À faire — Phase suivante
- **P2 — ≡ Menu management** : rename, reorder, delete, ajout grooves/patterns
- **Encyclopédie ≡** : édition de structure (ajout/suppression d'entrées)
- **Visualisation circulaire** : canvas rotatif synchronisé au playback
- **P3 — Parcours/étapes** : navigation TX (structure JSON prête, UI absente)
- **Sync prof→élève** : Google Apps Script ou export JSON

---

## Ce qu'on NE fait PAS en v2.0

- Mode Visibilité TX (endormi — champ JSON présent mais logique absente)
- Parcours/étapes navigation (P3 — structure JSON prête mais UI absente)
- Export MIDI
- Mode multi-utilisateur
- Mode sombre
- Rythmes sur bases impaires

---

## Référence v1.6

Le fichier `index.html` v1.6 contient les blocs à copier :
- Moteur audio (fonctions `scheduler`, `visualLoop`, `scheduleNote`, `getBeatSec`)
- Synthèse sonore (objet `SOUND_DEFS`, toutes les fonctions de synth)
- Visualisation circulaire (canvas, `visualLoopCircle`, `resizeCanvas`)
- Données encyclopédie (objet ou tableau des entrées)
