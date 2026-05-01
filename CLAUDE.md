# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~6000 lignes), vanilla JS, Supabase.
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
**v3.4.80** (session 2026-05-01)

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.4.49 | Nouvelles signatures : 7/4 (♩, 7 temps), 7/8 / 11/8 / 13/8 (♪ croche, aksak) ; encyclopédie `misc_signature` étendue |
| v3.4.69 | Bouton `+` tempo : `min-width:0` pour éviter overflow ; texte 3 colonnes MPV plus visible (noir clair / violet vif sombre) ; séparateur tap tempo |
| v3.4.70 | Bouton Tap centré, 1/3 de la ligne ; `metrics▶` à droite ; viz pattern centrée |
| v3.4.71 | Vue circulaire : rafraîchissement immédiat sur changement vitesse ×2/÷2 quand non-playing |
| v3.4.72 | Cycle vitesse : toujours passer par `=` (= → ×2 → = → ÷2 → = → …) |
| v3.4.73 | Overlay BPM corrigé ; overlay centré verticalement ; btn-view avant btn-metro ; btn-metro frameless ; approbation MX affiche auteur |
| v3.4.74 | Top bar grille 3 colonnes ; reset animation métro (`_lastMetroVizStep=-1`) |
| v3.4.75 | Viz métro toujours visible (hors sous-volet caché) ; `highlightMetroStep` temps-réel via `ac.currentTime - metroStartTime` |
| v3.4.76 | AudioContext `{latencyHint:'interactive'}` ; Page Visibility AC resume ; btn-vol → volet band ; `jouerOpen` ; Main G/D conditionnel |
| v3.4.77 | Alignement labels sections : `min-width:44px` sur `.section-bar-lbl` et `.btn-metro-main` (padding:0) |
| v3.4.78 | Recherche en temps réel dans les panels Patterns/Grooves/Bands ; export MIDI (modal note+canal par couche, tempo, signature) dans menu `…` |
| v3.4.79 | Recherche à droite du filtre famille (portrait : remonte au-dessus) ; ordre familles persisté en DB (MX) ; tap court btn-vol = mute/unmute toutes les couches ; metro subdivision indépendante du stepsPerBeat (stepSec = beatSec/subdivision) |
| v3.4.80 | Correctif critique : modal MIDI déplacé avant `<script>` (était après `</script>` → null.addEventListener crashait `attachEvents()` → tous les boutons morts) |

## Architecture tempo (slider #bpm)
- Le slider `#bpm` stocke des **SPM** (Steps Per Minute = vitesse de la croche)
- Le **BPM** musical est dérivé : `BPM = SPM / currentSig.stepsPerBeat`
- `stepsPerBeat` dans `SIGNATURES` : 2 pour ♩, 3 pour ♩., 4 pour ♩♩
- Préférence `prefs.sigChangeLock` : `'spm'` (croche constante) ou `'bpm'` (pulsation constante, défaut)
- Sur changement de métrique avec `sigChangeLock:'bpm'` : `newSPM = oldBPM × newSig.stepsPerBeat`
- `getMetroBeatSec()` = `(60/spm) * currentSig.stepsPerBeat` — beat métronome (sans `mult` ni `ternFactor`)

## Architecture vue circulaire

### Modes
- `circleModeView = 'measure'` (défaut) : 1 tour = 1 mesure complète
- `circleModeView = 'cycle'` : 1 tour = 1 cycle du pattern

### Mode Mesure — formules clés
- `measureSec = (60/spm) * stepsPerBeat * beatsPerMeasure`
- `maxRep = Math.ceil(measureSec / patternSec)` — nombre d'occurrences du pattern dans 1 mesure
- Angle du step `si` à la répétition `rep` : `frac = (si + rep*n) * getBeatSec(li) / measureSec`
- Occurrence active : `currentRepM = Math.floor(posInMeasure / patternSec)`

### Visual ghost (occurrences répétées)
- Même diamètre total que les steps normaux
- Fill à `dotR * 0.62` (anneau vide sur le bord extérieur)
- Stroke plein à `dotR`
- L'anneau "playing" n'est dessiné que sur `rep === currentRepM`

### Rafraîchissement automatique
`buildStepsDOM(li, wrap)` appelle `if(circleView) drawCircles()` en fin.
Couvre : chargement de pattern, tous les boutons mod, rotation, mute, changement de signature.

## Familles multi-axes (future session)
- Concept : tags multi-axes AND-filtrables (`style`, `metrique`, `feeling`, `difficulte`, `pedagogue`)
- Chaque item peut avoir plusieurs tags de différents axes
- UI : chips multi-select avec filtrage AND inter-axes
- DB : champ `category` dans `familles` à standardiser ; champ `scope` item-types optionnel
- **Ne pas implémenter avant décision archi concertée avec Lamberio**

## Tâches prioritaires (prochaine session)
1. **Familles multi-axes** — refactor tags multi-axes AND-filtrables (décision archi requise avec Lamberio)
2. **G1 Fork item école** — TX modifie un item école → copie automatique en source:'teacher' pour soumission
3. **G7 Raison de refus** — MX saisit un message lors du rejet, TX le voit dans le toast
4. **Migration DB familles** — appliquer `ALTER TABLE public.familles ADD COLUMN IF NOT EXISTS ordre int default 0;` sur Supabase

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
