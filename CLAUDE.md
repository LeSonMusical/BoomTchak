# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~10500 lignes), vanilla JS, Supabase.
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
- `index.html` — application complète (~9000 lignes)
- `BoomTchak_Explain.md` — référence complète (pédagogie + UX + technique + roadmap)
- `BoomTchak_v3_bible.md` — référence technique v3 (DB, RLS, workflows TX/MX)
- `supabase/schema.sql` — schéma Supabase (inclut toutes les migrations jusqu'à v3.7.0)
- `supabase/seed_school_pool.sql` — données initiales école

## Version courante
**v3.10.20** (session 2026-05-12)

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.10.20 | Refactor familles : PTK_DEFAULT source:'school' (fix rang grooves) ; type column sur familles (groove/pattern/both) ; band_familles + sound_familles branchées en DB (POST/PATCH/DELETE réels) ; _deletePending pour suppression famille band/sound via section Publier ; sbMergeSchoolData merge band/sound familles ; rename familles band/sound direct DB ; getFams() filtre par type |
| v3.10.19 | Modal preset : appui long famille → réordonner (MX) ; fix doublon famille (assigned sig uses familles_ids + guards lib-panel) ; préfs : slider décalage audio/image (-100..+300ms) + slider volume step doux (x, 5..80%) |
| v3.10.18 | grooveDirty propagé depuis metroDirty/bandDirty : saveGroovePattern gate sur `grooveDirty\|\|metroDirty\|\|bandDirty` ; updateGrooveSaveBtn reflète les trois flags ; setMetroDirty/setBandDirty rafraîchissent la disquette groove |
| v3.10.17 | Fix grooveDirty : swing et battue (felBeatSteps) marquent désormais grooveDirty → disquette '!' + section Soumettre/Publier |
| v3.10.16 | Toggle métro collapse/restore tous sous-volets (mémorise état) ; pm-close avec bordure visible ; isolation scroll modaux (body overflow hidden) ; couleurs adaptatives modal pattern/son par layer ; sync DB au démarrage même sans auth (sbSyncPublicPool) ; RLS anon presets DO $ block PG-compatible ; computeSigLabel corrigé (groupes / subdivision) ; signature fraction empilée ; suppression bordures metro-pat-row ; rebuild encyclo après sync public |
| v3.10.12 | Volet Unit : signature affichée inline à gauche des boutons < N > (sans bordure/fond, couleur neutre) ; Swing déplacé dans Unit (3e colonne) : % MPC au-dessus du slider, nom de style au-dessous |
| v3.10.11 | Swing MPC 50–75% : formule `offset = swingVal×0.5×stepDuration` (layers + métro) ; `getSwingName(mpcPct)` 8 niveaux (Straight→Dotted shuffle) ; `updateSwingDisplay()` ; swing déplacé de Tempo vers Unit |
| v3.10.10 | Vue Cycle linéaire : `totalU` = LCM des longueurs de patterns uniquement (signature exclue) ; `measU` = séparateur visuel seulement — cycle reflète la durée réelle des patterns |
| v3.10.9 | Volet Unit : remplacement de la grille haute par `metro-3col` compact ; boutons < > divisions (mpv-beats-btn) plus visibles ; suppression double bordure `tap-tempo-row` ; blanche = ♩♩, ronde = ○ dans unité |
| v3.10.8 | Refonte volets metro — Tempo (2 col : BPM large + Battement) ; Unit (3 col : Divisions + Unité + Swing) ; Métro (ctrl-row accents + pattern viz) ; `computeSigLabel()` → "2+3/8" depuis positions accents ; `updateSigDisplays()` ; `_applyDefaultsFromUnit()` auto-sync battement+subdiv ; symbole p → '-' dans renderMetroPatternViz |
| v3.9.0 | Volet Band : suppression bouton ≡ ; openPresetModal type:'band' — modes ✎ Gérer (rename, delete, familles) et ☰ Réordonner (drag-drop bands + familles) ; 💾 dans l'en-tête de chaque row son (toujours visible) ; TX/MX — section Soumettre/Approuver pour bands ; libDeleteBand, sbPublishBand, sbPushSchoolBandOrder ; table `bands` + `band_familles` dans schema.sql |
| v3.8.59 | Slider vol → sous-volet Vol (classe temps-slider) ; ordre boutons : Temps\|Sign\|Tap\|Vol\|Métro ; Temps ouvert par défaut |
| v3.8.58 | Fix sous-volets metro : Sign = sig-grid (Mesure/temps/subdiv) ; Temps = 3col seul ; boutons toggle avec état visuel open (fond violet + bordure + gras) |
| v3.8.57 | 4 sous-volets metro indépendants (Temps, Tap, Sign, Métro) ; Sign = ◀[label]▶ navigation preset (remplacé en v3.8.58) |
| v3.8.56 | Volet métro réorganisé en 3 sous-volets indépendants : Temps (BPM+sig), Tap, Métro (pattern viz) |
| v3.8.55 | sig-sel-btn affiche '—' si metroPattern embarqué (_embedded flag) ; donut repeated = même rayon ext. que disque plein (dotR pour isOn, dotR×0.72 pour isSoft) |
| v3.8.54 | Metro dirty complet : setMetroDirty sur swing, BPM ±, beat-val-input, beats/unité/subdiv (buildSigFromControls) + clic step mpv ; groove.metro embarque metroPattern si metroDirty ; applyGroove restaure metroPattern + setMetroDirty si embarqué |
| v3.8.53 | G7 raison de refus : MX saisit un motif (prompt) → PATCH reject_reason → TX voit toast individuels par item ; Swing persistance : groove.metro embarque swing+felBeatSteps+sig au save, applyGroove les restaure ; migration DB v3.8.53 (schema.sql) |
| v3.8.52 | donut = isRepeat uniquement ; isSoft = disque plein petit |
| v3.8.51 | ghost = répétitions de mesure ; silence sans anneau en vue Cycle |
| v3.8.50 | Revert donut universel : 'X' reste disque plein, seul 'x' (ghost) est pièce trouée ; isPlaying redessine le trou uniquement pour isSoft |
| v3.8.48 | Vue Cycle : linearCycleStartTime fixe l'aiguille sans recalibration ; anneau step courant par layer (rAF) ; édition circleHitTest linéaire ; metro subdivisions swingées (A+P non touchés) |
| v3.8.47 | swing-slider : classe temps-slider (violette, fine) ; metro-3col-bpm flex:1 → 3 colonnes égales |
| v3.8.46 | drawLinear WYSIWYE : positions X proportionnelles au temps réel (DENOM=6 units) ; Shuffle slider 0–100% dans volet metro ; 3 colonnes metro (BPM \| Battue \| Swing) ; SPM supprimé du volet |
| v3.8.43 | Séquences embarquées dans groove (gl.sequence) : pattern dirty → embed au save, pas de pollution DB ; nom pattern '—' si embedded ; _patOnSelect efface l'embed |
| v3.8.42 | Vue linéaire Cycle (↺ Cycle) : timeline PPCM horizontale, 3 rows layers, aiguille dorée |
| v3.8.40 | Metro topbar Option C final : icon + ♩=N permanent + mini-track 2px ; pointermove passive:false |
| v3.8.37 | SX par défaut : btn-layer-mod toujours visible ; canvas circulaire cliquable sans auth ; sbSyncPublicPool() au démarrage (anon key) + migration RLS v3.8.37 (schema.sql) |
| v3.7.0 | Familles métronome dynamiques : `metro_familles` DB, `familles_ids`+`ordre` sur `metro_presets` |

---

## Architecture temporelle (référence v3.8.11+)

### Principe fondamental
**1 step = 1 croche** à vitesse normale de pattern (sans ×2, ÷2 ni T ternaire).
Aucun changement de signature ne peut affecter la vitesse de lecture des layers.

### Variables clés

| Variable | Rôle |
|----------|------|
| `currentSig.felBeatSteps` | Nb de croches par battue ressentie (1=♪, 2=♩, 3=♩., 4=♩♩) |
| `currentSig.stepsPerBeat` | Nb de croches par temps théorique (idem felBeatSteps pour les sigs custom) |
| `currentSig.subdivision` | Nb de steps dans le métro.pattern par temps (≠ vitesse layers) |
| `#bpm` slider (pos 0–1000) | Encode le **BPM ressenti** via `posToBPM(pos)` |

### Fonctions de conversion

```js
posToSPM(pos)   = posToBPM(pos) × felBeatSteps   // croches/min
spmToPos(spm)   = bpmToPos(spm / felBeatSteps)    // position slider
getBeatSec(li)  = (60 / spm) / mult × ternFactor  // durée d'un step layer
```

`posToBPM(pos)` = BPM ressenti directement (le slider encode le BPM ressenti, pas le SPM brut).

### Vitesse de lecture des layers
```js
getBeatSec(li) = (60 / posToSPM(pos)) / mult × ternFactor
```
- `mult` : ×2 si doubleOn, ÷2 si halfOn (modification par layer)
- `ternFactor` : ×2/3 si ternOn (mode ternaire)
- **Indépendant de la signature** — la signature est purement cosmétique pour les layers.

### Vitesse de lecture du métronome
```js
stepSec = (60 / spm) × (stepsPerBeat / subdivision)
```
- `stepsPerBeat / subdivision` : ratio croches/step du métro.pattern
- La **subdivision** affecte uniquement le métro.pattern (pas les layers)
- Le **nb de temps** et l'**unité de temps** (beatUnit) sont cosmétiques (label seulement)

### Rôle des contrôles métriques dans le volet

| Contrôle | Effet sur lecture | Effet cosmétique |
|----------|-------------------|------------------|
| Battue `battue-sel` | ✅ Recalcule SPM (BPM ressenti constant) | ♪/♩/♩./♩♩ affiché |
| Nb de temps `mpv-beats-val` | ❌ Aucun | Label fraction gauche |
| Unité de temps `mpv-unit-sel` | ❌ Aucun | Label fraction droite |
| Subdivision `mpv-subdiv-sel` | ✅ Métro.pattern uniquement | Séparateurs visuels |
| BPM input `beat-val-input` | ✅ Recalcule SPM depuis BPM ressenti | `♩= N` affiché |
| Slider `#bpm` | ✅ Ajuste SPM directement | Nom tempo latin |

### Formule swing (v3.10.11+)
```js
// Offset sur steps impairs d'un layer :
const swOff = (swingVal > 0 && si % 2 === 1) ? swingVal * 0.5 * getBeatSec(li) : 0;
// Offset sur steps impairs du métro (subdiv) :
const swOffM = (swingVal > 0 && metroStepPos % 2 === 1) ? swingVal * 0.5 * (60/spmNow) : 0;
```
- `swingVal` : 0–1 → affichage MPC = `50 + swingVal×25` % (plage 50–75%)
- `getSwingName(mpcPct)` : Straight | Micro-swing | Lilt | Funk swing | Light shuffle | Triplet swing | Hard shuffle | Dotted shuffle
- Swing persisté dans `groove.metro` (embarqué avec le groove au save)
- Contrôle : slider dans volet Unit, colonne 3 (`.metro-3col-sw`)

### Sig et groove
- Changer de signature (`changeSig`) met à jour `groove.signature` **silencieusement** (pas de dirty, pas de publish).
- Le groove n'est marqué dirty que sur une modification explicite de pattern ou de paramètre musical.
- La section Soumettre/Publier pour les metro presets n'apparaît qu'après une **sauvegarde de preset** (bouton 💾).

### Presets métronome (`metroPresets`)
- Construits par `rebuildMetroPresets()` depuis `METRO_PRESETS_DEFAULT` + `packCours.metroPresets`
- Tous les presets (base, school, teacher) sont inclus — les presets teacher apparaissent en bas de liste
- `felBeatSteps` est stocké dans `packCours.metroPresets` (localStorage) mais pas en DB (pas de colonne)
- Indicateur dirty : `setMetroDirty(true)` sur modification de pattern ou de battue

---

## Tâches prioritaires — Session v3.9 : Volet Band

### Chantier principal : Gestion bands et sons (v3.9)
Le volet Band est le dernier grand chantier de gestion de presets à refactoriser selon le même modèle que Patterns/Grooves/Métro.

**État actuel :**
- `openPresetModal({type:'band'})` existe pour la **sélection** d'un band
- `openPresetModal({type:'sound'})` existe pour la **sélection** d'un son par layer
- `lib-panel-bands` est l'ancien panneau de gestion (à remplacer ou supprimer)
- Les sons (`SOUND_DEFS`) sont **hardcodés** en JS — hors scope (pas de CRUD son)
- Les bands sont stockés dans `packCours.bands` (localStorage + DB `grooves` via `band_defaut`)

**Objectifs v3.9 :**
1. **Modal Band — mode ✎ Gérer** : rename band, delete band, gestion familles (tags), même UX que patterns/grooves
2. **Modal Band — mode ☰ Réordonner** : drag-drop bands et familles, persistance DB (`sbPushSchoolBandOrder`)
3. **Symétrie TX/MX** : TX crée/modifie un band → section Soumettre ; MX approuve → section Publier
4. **Samples audio** : champ `sampleUrl` optionnel dans `SOUND_DEFS` ; si présent → playback `AudioBuffer` (fetch + decodeAudioData), sinon fallback synthèse oscillateur existant

**Questions à trancher avec Lamberio avant de coder :**
- Quelle est la source des samples ? (bibliothèque libre incluse dans le repo ? URL externe ? Upload MX via Supabase Storage ?)
- Le CRUD band TX/MX doit-il passer par la même table DB que les grooves, ou une table dédiée `bands` ?
- Un band = liste ordonnée de sons par layer ; la structure actuelle est-elle suffisante pour v3.9 ?

### Autres chantiers en attente
- **Samples audio** — Cadrer la source avec Lamberio, puis implémenter `sampleUrl` dans SOUND_DEFS

### Roadmap court terme — Bouton REC dans le volet Mod des patterns

**Idée produit :** Ajouter dans le volet Mod de chaque layer (côté droit, sur chaque couche) 3 boutons :
- **⏺ Rec** — entre en mode enregistrement ; les sons joués avec les boutons Main G/D pendant la lecture s'inscrivent dans le pattern courant au pas le plus proche (quantization au step)
- **⌫ Clear** — efface le pattern courant (met tout à '.')
- **⎘ Copier/Coller** contextuel — copie le pattern du layer courant ; s'il existe un pattern dans le presse-papier, propose coller à la place

**Fonctionnement du REC :**
- Nécessite lecture active (`playing`)
- `state[li].recording = true` → chaque pression `playConga` (ou futur bouton layer dédié) calcule le step courant : `Math.round((now - state[li].startTime) / getBeatSec(li)) % n`
- En mode rec à 2 mains (sin2 pattern) : bouton Main G → layer thumbL, bouton Main D → layer thumbR
- Visual : layer en mode rec passe en rouge pulsant (animation CSS)
- Durée max : 2 mesures ou 1 cycle pattern, puis auto-stop rec

**Complexité estimée :** modérée — 4 à 6h. Les primitives de timing existent déjà (`getBeatSec`, `state[li].stepPos`, `state[li].nextStepTime`). La quantization au step est triviale. Le plus délicat est la gestion de l'UX (countdown avant rec ? feedback visuel précis ?). À cadrer avec Lamberio avant de coder.

## Résolu (session 2026-05-10 — v3.10.8–v3.10.12)
- ✅ **Refonte volets metro** — Tempo (BPM large + Battement) | Unit (Divisions + Unité + Swing) | Tap | Vol | Métro ; remplacement de Sign/Temps par Tempo/Unit
- ✅ **computeSigLabel()** — génère "2+3/8" en lisant les positions des accents A dans metroPattern
- ✅ **_applyDefaultsFromUnit()** — auto-sync battement et subdivision depuis l'unité choisie
- ✅ **Swing MPC 50–75%** — formule `offset = swingVal × 0.5 × stepDuration` (layers + métro) ; `getSwingName()` 8 niveaux nommés
- ✅ **Swing → volet Unit** — colonne 3 avec % MPC au-dessus du slider et nom de style au-dessous
- ✅ **Signature inline Unit** — `sig-edit-val` neutre (pas de bordure/fond) inline à gauche des < N > divisions
- ✅ **Vue Cycle LCM patterns only** — `totalU` calculé sur les longueurs de patterns uniquement, signature = séparateur visuel

## Résolu (session 2026-05-06 — suite)
- ✅ **5 sous-volets metro** — Temps (3col BPM+Battue+Swing) | Sign (sig-grid Mesure/temps/subdiv) | Tap | Vol (slider) | Métro (pattern viz) ; Temps ouvert par défaut
- ✅ **Boutons toggle visuels** — état open = fond violet léger + bordure + gras (`.btn-metro-volet.open`)
- ✅ **Volume → sous-volet Vol** — slider violet pleine largeur, retiré de la section bar (problème affichage petit écran)

## Résolu (session 2026-05-06 — v3.8.53–56)
- ✅ **Donut universel** — 'X' (son fort) passe en pièce trouée comme 'x' ghost ; trou dotR×0.30 pour fort, dotR×0.27 pour ghost
- ✅ **Vue Cycle aiguille + steps animés** — `linearCycleStartTime` fixe ; anneau coloré autour du step courant par layer (rAF)
- ✅ **Metro swing subdivisions** — level='p' reçoit `swingVal×(60/spm)/3` sur steps impairs ; A et P non touchés
- ✅ **drawLinear WYSIWYE** — X proportionnel au temps réel (DENOM=6 units, LCM temps-réel)
- ✅ **G7 raison de refus** — MX saisit motif → PATCH reject_reason → TX voit toast individuels
- ✅ **Swing + metro persistance groove** — `groove.metro` jsonb embarque swing, felBeatSteps, sig, metroPattern (si dirty)

## Résolu (session 2026-05-04)
- ✅ **Artefact bord canvas vue circulaire** — `resizeCanvas` utilise `cv.style.width/height` au lieu de `transform:scale` ; `max-width/height` supprimés du CSS
- ✅ **Cadre btn-view gris uniforme** — suppression `border-color:#d4b86a` dans `.groove-bar .btn-view` ; cadre gris `#ccc` partout
- ✅ **Labels vue circulaire étendus** — 2 lignes par layer : "Np de UNIT" + "D temps" ; `CIRC_LABEL_W=90` ; unité = 1/8, 1/16, 1/4, 1/8T, 1/16T, 1/4T selon doubleOn/halfOn/ternOn ; durée = n×tf/(fbs×mult)
- ✅ **Toolbar encyclo sur mobile (clavier OS)** — Visual Viewport API `transform:translateY(vv.offsetTop)` maintient la toolbar dans la zone visible
- ✅ **Labels nb de pas vue circulaire mesure** — 3 pastilles colorées en coin sup. gauche du canvas, mises à jour en temps réel au resize
- ✅ **canOverwrite MX pattern/groove** — MX peut écraser un item école quel que soit le mode courant → modifications tracées dans section Publier
- ✅ **Désync audio/visuel au changement de pattern** — `_patOnSelect` fixe `startTime = nextStepTime` pour aligner step 0 visuel et audio
- ✅ **1er temps métro décalé au changement de groove** — `applyGroove` synce sur `mpLen` (début de mesure = pos 0 du metroPattern) au lieu de `subdivision` (temps quelconque)
- ✅ **Mute band ignoré au changement de groove** — `applyGroove` préserve `_wasMutedAll` (classe 'muted' du btn-vol) avant d'appliquer les états du nouveau groove
- ✅ **Cadre btn-view ⊞/◎** — `border:1px solid` aligné sur pm-preset-btn (v3.8.29)

## Résolu (session 2026-05-02 — gestion preset métronome + timing)
- ✅ **6 bugs preset métro** — dirty indicator, preset teacher visible immédiatement, bouton Écraser, battue sans recalcul tempo, sig discrète, nom par défaut = label courant
- ✅ **Mode BPM constant** — fix `changeSig` utilise `oldSig.felBeatSteps` (stepsPerBeat était utilisé → bug sur aksak)
- ✅ **Affichage SPM** — `♪/min` sur ligne 1 du volet, mis à jour par `updateBeatDisplay()`
- ✅ **Refacto posToSPM** — utilise `felBeatSteps` au lieu de `stepsPerBeat` ; slider = BPM ressenti toujours
- ✅ **buildSigFromControls cosmétique** — unité/nb-temps ne changent plus stepsPerBeat ni grooveDirty
- ✅ **changeSig silencieux** — plus de dirty/publish sur changement de signature
- ✅ **Icône ♩♩** pour felBeatSteps=4 (blanche → 2 noires)

## Résolu (session 2026-05-02 — amélioration section métronome)
- ✅ **Suppression lib-panel-metro** — remplacé par modal sig
- ✅ **Bug tempo en lecture** — rescale `metroNextBeatTime` proportionnel lors du changement slider
- ✅ **felBeatSteps** — paramètre "battue" éditable par preset (♪♩♩.♩♩), persisté en DB
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
    getFilteredItems()  → items filtrés (famFilter + searchQuery) ; sig : teacher en bas
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

---

## Encyclopédie — Cahier des charges des articles concept

### Structure d'un article (8 sections)

| # | Titre de section | Contenu |
|---|-----------------|---------|
| 1 | **En bref** | L'essentiel en 3 phrases courtes, accessible à tous |
| 2 | **En théorie** | Définition formelle, terminologie précise |
| 3 | **En pratique** | En situation de musicien — exemples, ressenti, analogies |
| 4 | **Dans BoomTchak** | Pointer l'UI concerné, expliquer les usages concrets |
| 5 | **Pour aller plus loin** | Approfondissements spécifiques (ex : tempo absolu vs ressenti, machine vs humain) |
| 6 | **Histoire / Culture / Écriture** | Selon pertinence de la notion (pas toujours présent) |
| 7 | **Voir aussi** | Liens vers articles connexes |

### Règles de rédaction
- Accès direct à une section depuis un autre article (système d'ancres : `article#section`)
- Chaque section : titre + contenu ; à l'intérieur d'un contenu : aller à la ligne entre paragraphes
- Ton pédagogique, pas condescendant — le musicien est au centre
- Pas de jargon non défini dans l'article lui-même

### Liste des 12 articles validés
`Tempo` | `Mesure` | `Temps` | `Pulsation` | `Division` | `Rythme` | `Pattern` | `Groove` | `Syncope` (+ Contretemps) | `Polymétrie` | `Shuffle` | `Cycle`

### Format DB cible (extension à prévoir)
Le format actuel `{ chapo, bullets }` est insuffisant pour 8 sections nommées avec ancres.
Structure cible :
```js
packCours.encyclo[key] = {
  titre: string,
  sections: [
    { id: 'en-bref',       titre: 'En bref',       contenu: string },
    { id: 'en-theorie',    titre: 'En théorie',    contenu: string },
    { id: 'en-pratique',   titre: 'En pratique',   contenu: string },
    { id: 'dans-boomtchak',titre: 'Dans BoomTchak',contenu: string },
    { id: 'plus-loin',     titre: 'Pour aller plus loin', contenu: string },
    { id: 'culture',       titre: 'Histoire / Culture / Écriture', contenu: string },  // optionnel
    { id: 'voir-aussi',    titre: 'Voir aussi',    liens: string[] }
  ]
}
```
Migration DB : champ `bullets jsonb` étendu ou remplacé par `sections jsonb`.

---

## Conventions
- Commentaires en français, code en anglais
- Pas de framework, pas de bibliothèque externe
- Mobile-first (testé sur smartphone)
- Écriture de gros fichiers : utiliser scripts bash/heredoc, jamais le Write tool direct
