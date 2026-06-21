# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~15800 lignes), vanilla JS, Supabase.
Lire `BoomTchak_v3_bible.md` et `BoomTchak_Explain.md` avant toute modification.

## Principe WYSIWYH (What You See Is What You Hear) — règle absolue

**Tout ce qui est affiché dans l'interface doit correspondre exactement à ce qui est joué.**

- La vue Mesure affiche la tranche du pattern en cours de lecture (système de pages tournantes). Si le pattern fait 3 mesures, la page 1 montre ce qu'on entend à la mesure 1, la page 2 ce qu'on entend à la mesure 2, etc.
- La vue Motif affiche toujours le cycle complet du pattern.
- La vue Cycle affiche le PPCM de tous les layers (ce qu'on entend sur un cycle complet).
- Toute modification qui casserait ce principe doit être soumise à Lamberio avant d'être implémentée.

## Règles de collaboration
- Lamberio = product owner. Questions archi importantes → soumettre AVANT de coder.
- Langue : français. Variables/fonctions : camelCase anglais.
- Version `MAJEUR.MINEUR.PATCH` bumpée à chaque commit (dans `<span class="app-version">`).
- **SQL migrations** : tout script SQL à exécuter par Lamberio (migration, seed, correctif DB) doit être écrit **directement dans l'interface de chat Claude**, pas uniquement dans la description de la PR ou dans les fichiers.

## Cadrage v3.26 — Session 2026-06-12 (validé par Lamberio)

### Trois modes d'usage (grille de lecture UX validée)
1. **Écouter / jouer** — play, mute, tempo : toujours accessible, ne se replie jamais
2. **Regarder / comprendre** — choix de vue, infos cycle/mesure/temps : contextuel au canvas
3. **Éditer / créer** — steps, length, rate, transformations, presets : sur demande, profond

> Principe directeur : un contrôle est placé selon son **mode d'usage**, jamais selon la zone qu'il pilote. Les contrôles du mode « écouter » ne se replient jamais.

### Architecture validée : 3 barres
- **GlobalControlBar** : métro on/off + son on/off + tempo + signature + switch d'affichage Groove.view / Layer.view (+ éventuellement play)
- **LayerControlBar** : pour chaque layer, dans l'ordre de priorité/accessibilité directe : on/off (mute), afficher/masquer le layer (pliage individuel), contrôles principaux (nb de pas + unité de pas via un geste simple de glissé), infos contextuelles layer
- **GrooveControlBar** : liée à l'affichage Groove.view — les 4 vues, infos et accès contextuels (dépendants de la vue), infos globales « où suis-je dans le temps »

**Décisions actées :**
- Le **play reste dans la bottom-bar** (qui garde son rôle de NavBar)
- Question ouverte en cours : où et comment disposer les barres, notamment la LayerControlBar

### Décisions actées — Audit UX session 2026-06-12 (soir, validé par Lamberio)
- **GlobalControlBar = barre séparatrice "vivante"** entre Groove.view (haut) et Layers.view (bas) : métro on/off + tempo (drag) + 3 pastilles mini-VU fusionnées avec le mute par layer + son global on/off + poignée splitter. Ne se replie jamais.
- **Modèle 3 états du splitter** (le splitter règle l'**espace**, pas le mode) : `A Groove max` (canvas plein, pas de volets layer) / `B Split` (défaut — canvas + lignes steps, accordéon exclusif des volets) / `C Layers max` (canvas replié, pastilles VU = résumé vivant). Drag de la GlobalControlBar avec snap sur 3 positions.
- **LayerControlBar** : mini-barre 3 segments colorés, placée sous la GlobalControlBar, toujours visible. Par segment : tap = plier/déplier le volet layer ; **drag vertical = échelle de grain iso-durée** (4♩ ↔ 8♪ ↔ 12♪T ↔ 16♬ ↔ 24♬T ↔ 32 — change nb pas + unité ensemble à durée de cycle constante ; le ternaire est un barreau de l'échelle) ; **drag horizontal = rotation/décalage du motif**. Affiche `NbPas·unité`. Le length pur (polymétrie) reste dans le volet déplié. Variante "segments sur les flancs du cercle" (vue circulaire) = raffinement responsive à prototyper plus tard.
- **Modèle 4 axes "squelette & chair"** pour le mod gestuel (validé) : 1. **Densité** du squelette (nb de X) · 2. **Géométrie** (groupé ↔ équilibré/euclidien, interne a-métrique) · 3. **Calage** (rotation → perçu comme sur-le-temps ↔ contretemps, externe métrique) · 4. **Remplissage/liant** (densité des ghosts x dans les trous). L'accent n'est plus un paramètre : c'est la frontière squelette/chair. Chaque axe = un phénomène audible nommable + un article encyclo. Axes = lentilles déterministes et réversibles (ancre ↺ vers motif d'origine).
- **Totems verticaux** (mod gestuel, 1 colonne par layer : mini-anneau + pad 2D densité↕/calage↔ + jauges géométrie/liant + ↺) : **découplés du splitter** — toggle explicite `☰ lignes / ▥ totems` dans Layers.view. **La vue mod actuelle est conservée de côté** (les totems viennent en plus, pas en remplacement).
- **Maquette jetable** : `maquette_v326.html` (fichier autonome à la racine, audio synthèse incluse) pour tester les gestes au pouce sur smartphone via GitHub Pages. Ne fait pas partie de l'app.

### Retours Lamberio sur maquette it.1 → décisions it.2 (2026-06-12 soir)
- **Play aussi dans la GlobalControlBar** (en plus de la bottom-bar) : les testeurs font souvent play/stop et sont agacés par la boucle qui tourne sans arrêt — le play/stop doit être très accessible. À l'essai dans la maquette.
- **LayerControlBar** : drag ↕ grain iso-durée ✅ conservé ; **drag ↔ calage supprimé** ; tap = montrer détail du layer (contenu du détail à définir). Si un second glissé est ajouté, ce sera pour la **densité** (à l'essai en ↔ dans la maquette it.2).
- **Bouton ↺ (retour au motif d'origine)** : validé, emplacement à revoir.
- **Vue lignes (édition)** : les **presets sont l'essentiel** (+ i + 🎲) — toujours visibles par layer. Tête de lecture obligatoire (WYSIWYH).
- **Totems = mode création** : l'essentiel = les gestes-interface de création. **2 pads par layer** : pad A squelette = densité↕ · géométrie↔ ; pad B chair = liant↕ · calage↔ ; + boutons 🎲 placement aléatoire et 🎲 accents aléatoires. Garder les paramètres génératifs de l'ancienne version mod.
- **Mini-anneaux par layer** : inutiles quand Groove.view est visible au-dessus ; **affichés seulement en état C** (Layers max).
- **Vue "mesure iso-métrique" découverte par accident** (cellules de step à largeur proportionnelle à la durée, flex) : intermédiaire entre la vue Cycle (linéaire, 1 tête de lecture) et la vue Step.seq (pas égaux, 3 têtes). **À garder de côté comme candidate 5e vue.**

### Retours Lamberio sur maquette it.2 → décisions it.3 (2026-06-12 nuit)
- **⚠️ Design maquette ≠ design final** : les partis pris visuels de la maquette (plus rond, plus gros, couleurs différentes) ne sont a priori PAS à conserver. Les choix validés devront être appliqués **au design de la version actuelle** de l'app. La GlobalBar de la maquette est jugée moche.
- **Toggle ☰ édition / ▥ totems déplacé sur la LayerControlBar** (extrémité droite).
- **Vue classic (édition), boutons par layer** : presets ◀▶ + 💾 save + ↺ retour + i + 🎲 random + ⏺ rec.
- **Mute layer → état désactivé visible partout** : segment LCB grisé + couche grisée dans les vues layer.
- **Overlays drag : sur les barres (Global/Layer) uniquement, PAS sur les éléments des totems** (le feedback des pads = le pattern lui-même).
- **Cohérence gestuelle : densité toujours en X** (comme le drag ↔ de la LCB) → pads : A = densité↔ · géométrie↕ ; B = liant↔ · calage↕.
- **Labels d'axes des pads** : noms en texte au milieu des axes vertical/horizontal, sans icônes.
- **Totems adaptatifs** : layer plié (tap LCB) = totem masqué, les autres s'élargissent (pads plus grands à 2 ou 1 layer).
- **Placement GlobalBar = vrai sujet ouvert** : idéal = correspondance 1:1 entre les 3 pastilles et les 3 segments LCB + proximité tempo/métronome. **Proposition it.3 à valider : pastilles VU/mute déplacées DANS les segments LCB** (à gauche de chaque segment) ; la GCB devient ▶ ⏱ tempo 🔊.
- **Question ouverte (redondance double vue)** : quel sens d'avoir une step view en haut (Groove.view) ET les lignes en bas ? Piste de reclassification : Motif/Mesure/Cycle = vues de **contexte** (vivent en état Split au-dessus des lignes) ; Step.seq = une **présentation de Layers.view** (pas une Groove.view — c'est déjà le cas techniquement : `_moveRow2ToStepView`). À trancher.

### Retours Lamberio sur maquette it.3 → décisions it.4 (2026-06-13)
- **Placement GCB/LCB validé** (pastilles dans les segments LCB).
- **Segments LCB, ordre : [pastille][nb pas][unité][chevron]**, chevron nettement plus gros.
- **GCB : ⏱ métro (extrême gauche) | tempo | ▶ Play (centre) | signature | 🔊 band (extrême droite)**.
- **🎲 de la barre layer = random PRESET** (tirage dans la liste des presets), pas random pattern.
- **[nb pas][unité] retirés de la barre layer** (déjà affichés dans la LCB).
- **Pads : nom de l'axe vertical à gauche (texte tourné), nom de l'axe horizontal en bas.**
- **Non-choix assumé (vue détaillée layer)** : 2 boutons à gauche de la LCB — `👁` afficher/masquer la vue détaillée du layer ; `v25/v26` switcher entre style édition classique v3.25 (pas tous de même taille) et style v3.26 test (iso-métrique, largeur ∝ durée). À trancher à l'usage. Reste aussi ouvert : la ligne sous la barre preset = vue steps ou sous-volet mod v3.25 ?
- **Réorganisation des pads (hypothèse Lamberio, implémentée it.4)** : pad **Densité** = densité des accents ↔ · liant/remplissage ↕ ; pad **Placement** = décalage ↔ · géométrie ↕ (bas = euclidien → haut = regroupé).
- **Décalage fort/faible — formalisation** : rotation totale `r = b·spb + s` (spb = pas par temps). `s` (intra-temps, 0..spb-1) = **offset FORT** : change le poids métrique, les sons sur temps fort passent à contretemps → axe X du pad Placement (crans). `b` (temps entiers) = **offset FAIBLE** : rotation réelle mais chaque son garde sa position dans le temps (le poids ne bouge pas) → boutons `◀t / t▶` du totem. Méthode de calcul et geste à valider à l'oreille.

### Chantiers suivants (après les barres v3.26)
- **Vue verticale type console de mixage + redesign du sous-volet mod** (sliders, pad 2D plus graphique et gestuel) — chantier suivant
- **Gestes sur le canvas — à creuser ultérieurement** : appui court/long sur step (édition directe), drag radial (rotation/shift), pinch (length ?), zoom… Conflits gestuels (scroll, tap accidentel pendant l'écoute) à prototyper avant tout engagement. Le hit-test circulaire existe déjà (`circleHitTest`).

## Direction design UI — Session 2026-06-12

### Structure bandeau validée pour tous les volets (v3.25.11)
Tous les volets bottom-sheet adoptent la même grille `1fr auto 1fr` avec :
- **Gauche** : action principale du volet (`＋` Groove, `🥁 Kit` Sons) ou rien
- **Centre** : `[🎲] ◀ [preset name] ▶ [💾] [✨]` — tout l'interactif proche du nom
- **Droite** : `[i]` (si article encyclo) + `[✕]` fermeture

Détail par volet :

| Volet | Gauche | Centre | Droite |
|-------|--------|--------|--------|
| **Groove** | `＋` | `🎲 ◀ Groove ▶ 💾` | `i` |
| **Sons** | `🥁 Kit` | `🎲 ◀ Band ▶ 💾 ✨` | `i ✕` |
| **Encyclo** | *(spacer)* | `🎲 ◀ Article ▶ 💾` | `✏️ ✕` |
| **Métro** | `⏱ ON/OFF` | `◀ 4/4 ▶ 💾` | `i ✕` |
| **Settings** | `👤 rôle` / `← retour` | *(spacer)* | `✕` |

**Règle clé :** `💾` utilise `visibility:hidden` (jamais `display:none`) → le preset reste toujours visuellement centré, même quand propre.

**Bouton ✨ global Sons** : new preset aléatoire dans la même famille + randomisation pitch/atk/env, pour les 3 layers simultanément.

### Panels bottom-sheet — auto-height (v3.25.x)
- **Settings** : `_settingsPanelFitH()` = `handle + header + content.scrollHeight` (jamais `panel.scrollHeight` qui rate les enfants flex `min-height:0`)
- **Sons** : `_bandPanelFitH()` idem ; `_resizeBandPanel()` appelé directement depuis le handler ⚙▼/▶ de chaque layer (ResizeObserver ne fonctionne pas sur `overflow-y:auto`)
- **Prefs Settings** : `_resizeSettingsPanel()` avec `transition='none'` avant le resize pour éviter l'animation lente

### Bug corrigé — volet Workflow MX (v3.25.10)
`buildPublishSection()` posait `container.style.display='none'` quand aucun item, mais ne le réinitialisait jamais à `''` lors des appels suivants avec items. Fix : `container.style.display=''` ajouté après le bloc early-return. `buildApprobationsSection()` : hide silencieux quand vide (plus de "Aucun contenu en attente" trompeur).

## Direction design UI — Session 2026-06-07

### Décision acte : suppression des bordures latérales jaunes (v3.20.32)
Les bordures `border-left: 2px solid #C8961A` et `margin-left: 4px` qui couraient le long du canvas, des layers, de la view-mode-bar et du step-sequencer ont été supprimées. Le contenu Groove est désormais pleine largeur.

**Raisonnement :** signal redondant (le canvas communique déjà la zone Groove), espace volé (~10px), artefact visuel asymétrique, incohérence avec le paradigme drawer de Capture/Jeu.

### Principe directeur validé
> **Le seul signal coloré qui mérite de persister est celui des layers** (bleu/rouge/vert) — parce qu'il a une fonction de décodage direct : cette couleur = cette couche dans le canvas = ces boutons.
> Tout le reste (couleurs de section : jaune Groove, teal Metro, bleu Band) est un repère secondaire, pas un délimiteur spatial.

### Deux systèmes coexistent — unification quasi-complète
L'appli mélange deux paradigmes :
- **Volet empilé** (Groove uniquement) — architecture originale, toujours verticale
- **Drawers pleine largeur bottom-sheet** (Sons/Band, Capture, Jeu, Métronome, Encyclo, Settings) — paradigme unifié, meilleur sur mobile ✅

**Métronome (v3.23)** : bottom-sheet deux onglets (♩= Tempo | ▣ Battue). Cadran rotatif pour le tempo, jauges horizontales pour les volumes, picker BeatUnit flottant, tap tempo avec décompte.

**Sons/Band (v3.24)** : bottom-sheet activé par nav-tab → slide-up depuis le bas, hauteur drag-réglable. ✅

### Ce qui ne change PAS
- Les couleurs de section (`#C8961A` jaune Groove, `#3A8C6E` teal Metro, `#2d5f80` bleu Band) restent comme codes d'identité dans les headers de section et les accents (boutons, badges)
- Les borders jaunes des **headers de section** (`.groove-bar`, `.temps-bar`, `.band-bar`) sont conservées — elles délimitent le header, pas le contenu
- La bottom-bar garde sa `border-top: 2px solid #C8961A` — elle ancre l'appli visuellement

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
| Famille band | n/a | ✅ MX direct DB (_pmStartRenameFamille) | n/a | ✅ MX POST band_familles | ✅ MX PATCH band_familles | ✅ _deletePending→Publier |
| Famille son | n/a | ✅ MX direct DB (_pmStartRenameFamille) | n/a | ✅ MX POST sound_familles | ✅ MX PATCH sound_familles | ✅ _deletePending→Publier |

### Gaps connus (à traiter)
- `GAP_ENC_DEL` : Pas de delete encyclopédie TX ni MX (hors scope actuel)

### Gaps résolus (session 2026-05-13)
G1 (fork école TX), G2 (familles TX soumission), G3 (annulation auto Supabase), G4 (MX save DB), G5 (encyclo MX→DB), G7 (raison de refus), G9 (delete école UI MX) — tous implémentés et vérifiés.

### Long terme
- G6 (tempo min/max) : abandonné — `tempo.defaut` suffit
- G10 (historique soumissions) : long terme

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
- `index.html` — application complète (~15800 lignes)
- `BoomTchak_v3_bible.md` — référence technique v3 (DB, RLS, workflows TX/MX)
- `supabase/schema.sql` — schéma Supabase (inclut toutes les migrations jusqu'à v3.14.15)
- `supabase/seed_school_pool.sql` — données initiales école

## Version courante
**v3.28.39** (session 2026-06-21)

---

## Architecture Vue Totems — Génération de patterns (v3.27)

### Principe général
La Vue Totems (toggle 🪄/☰ dans la LCB) propose un mode de création gestuel : 2 pads XY par layer, qui génèrent le pattern en temps réel. Chaque paramètre correspond à un phénomène musical distinct et nommable.

### Les 4 axes

| Axe | Pad | Direction | Formule | Phénomène musical |
|-----|-----|-----------|---------|------------------|
| **Densité** | A | ↔ (X) | `k = round(x·L)` accents X | Nombre de frappes fortes |
| **Remplissage** | A | ↕ (Y) | `nSoft = round(s·(L−k))`, priorité poids métrique | Ghostings/fills entre les frappes |
| **Géométrie** | B | ↕ (Y) | Lerp euclidien→bloc | Forme : répartition régulière ↔ bloc compact |
| **Calage** | B | ↔ (X) | `r = calB·spb + calS` rotation interleaved | Décalage dans le temps : sur-le-temps ↔ contretemps |

### Formule `generatePatternFromPad(li, x, y, s)`

```js
// 1. Placement euclidien des k accents (Bresenham)
eucPos[i] = floor(i·L/k)   pour i = 0..k-1

// 2. Géométrie : lerp euclidien (y=0) → bloc consécutif (y=1)
raw[i] = round(eucPos[i]·(1-y) + i·y)   avec raw[i] ≥ raw[i-1]+1

// 3. Remplissage : score de priorité des silences restants
score[i] = weight[i]·(1-noise) + rv[i]·noise
// weight issu du metroPattern : A=1.0 P=0.5 subdiv=0.1
// noise = 0.12 + max(0, 2s-1)^1.3 · 0.62  (croît dans la 2e moitié)
// Les positions métriquement légères sont remplies en premier
```

### Formule calage — `_applyTotemAB(li)`

```js
// Mapping interleaved : premiers crans = offset faible (poids préservé)
//                       crans suivants = offset fort (bascule poids métrique)
const idx  = round(xB·(L−1))
const calS = floor(idx / BEATS)   // 0..spb-1 = offset intra-temps (fort)
const calB = idx % BEATS           // 0..BEATS-1 = offset inter-temps (faible)
const r    = calB·spb + calS      // rotation totale appliquée au pattern
```

### Verrou calage pur (`_totemPadBLocked[li]`)

Bouton 🔒 top-right du pad B. Quand actif :
- Le squelette est gelé (`_totemLockedPat[li]` = snapshot à l'activation)
- Pad B X → rotation delta depuis le début de chaque geste (`_totemLockedXB[li]`)
- Pad B Y → ignoré
- Pad A → désactivé (`pad-a-locked` : cursor not-allowed)

### Preview constellation circulaire

Les dots du pattern sont positionnés en cercle dans chaque pad :
```js
a = (i/L)·2π − π/2   // départ en haut
left = (50 + 36·cos(a)) + '%'
top  = (50 + 36·sin(a)) + '%'
```
- Pad A : montre le pattern **avant calage** (`_totemPreRotPat[li]`) — la forme géométrique pure
- Pad B : montre le pattern **après calage** — on voit la constellation tourner quand on glisse
- Forte (X) = glow double (box-shadow 5+10px couleur layer) ; soft (x) = halo léger ; silence = étoile grise

### État — variables module-level

```js
_totemPadAState  [{x,y}×3]  // densité(x) / remplissage(y)
_totemPadBState  [{x,y}×3]  // calage(x) / géométrie(y)
_totemPadBLocked [bool×3]   // mode calage pur
_totemLockedPat  [pat×3]    // pattern gelé à l'activation du verrou
_totemLockedXB   [0..1×3]   // xB au début du geste (référence delta)
_totemPreRotPat  [pat×3]    // snapshot entre generatePatternFromPad et rotate
_totemOrigPat    [pat×3]    // pattern au moment de l'entrée en mode Totem (↺)
_softRandVals    [[r]×3]    // vecteur aléatoire fixe pour le remplissage
                             // re-seedé uniquement au pointerdown du pad A
```

---

## Architecture Métronome — Signature (v3.27)

### Colonne gauche (`.metro-col-metric`)

Structure HTML de la fraction verte :

```
<span class="metro-metric-lbl">Divisions</span>
<div class="metro-frac-num-row">                     ← numérateur
  <button class="mpv-beats-btn" id="mpv-beats-down">
  <span class="mpv-beats-val metro-frac-n" id="mpv-beats-val">4</span>
  <button class="mpv-beats-btn" id="mpv-beats-up">
</div>
<div class="metro-frac-bar">                         ← trait vert
<div class="metro-frac-num-row">                     ← dénominateur
  <button class="mpv-beats-btn" id="mpv-den-down">
  <button class="metro-frac-d metro-frac-n" id="metro-frac-den">4</button>  ← tap → picker
  <button class="mpv-beats-btn" id="mpv-den-up">
</div>
<span class="metro-metric-lbl">Unité</span>
```

**Piège CSS** : `button.metro-frac-d` a une spécificité 0,1,1 qui écrase `.metro-frac-d` (0,1,0). Ne JAMAIS utiliser `font:inherit` dans cette règle — cela réinitialise `font-size:26px`. Toujours spécifier `font-size:26px;font-weight:900;font-family:inherit` explicitement.

**Centrage** : `.metro-col-metric` utilise `justify-content:center` (ne pas revenir à `flex-end`).

### Picker unité (`#sig-den-picker`)

Popup fixe (z-index:9999) ouvert au tap sur `#metro-frac-den`. 4 options : ♩♩/2, ♩/4, ♪/8, ♬/16.

### `_applyDenUnit(newBu)` — règle importante

Cette fonction est définie dans un bloc local (`if(denEl&&sdPick){...}`). Elle **ne peut pas** appeler `_naturalBeatTimeUnit` qui est elle aussi locale (définie dans le bloc chips à la ligne ~11709). Utiliser **`_applyDefaultsFromUnit()`** (globale, hoistée) à la place :

```js
const _applyDenUnit=newBu=>{
  const mpvU=document.getElementById('mpv-unit-sel');
  if(mpvU) mpvU.value=newBu;
  if(typeof _applyDefaultsFromUnit==='function') _applyDefaultsFromUnit(); // ← calcule la battue
  const batSel=document.getElementById('battue-sel');
  if(batSel) batSel.dispatchEvent(new Event('change')); // ← propage au handler SPM
  if(typeof buildSigFromControls==='function') buildSigFromControls();
  if(typeof _syncUnitChips==='function') _syncUnitChips();
};
```

### Double ID `mpv-unit-sel`

Il existe deux éléments avec cet ID dans le DOM :
1. `<select id="mpv-unit-sel" style="display:none">` — dans `.metro-col-metric` (caché, utilisé comme référence par `buildSigFromControls`)
2. `<select class="mpv-sel mpv-sel-sm" id="mpv-unit-sel">` — dans la colonne 3-cols Unité (visible, interaction directe utilisateur)

`getElementById` retourne toujours le **premier**. Toutes les lectures/écritures programmatiques ciblent le premier. Cette dualité est un vestige à nettoyer à terme.

---

## TODO — Migration items hard-codés vers DB

Les éléments suivants sont encore hard-codés dans le JS et doivent être migrés en DB (sauf sons) :

### 1. Articles encyclopédie (`const ENCYCLO` + `const ENCYCLO_MISC`)
- **17 articles patterns rythmes** : `fl4/offbeat`, `tres`, `cinq`, `hab`, `afoxe`, `reggae`, `son/son23`, `shiko`, `souk`, `bossa`, `gahu`, `samba`, `fume`, `cascara`, `tumbao`, `solea`, `bembe`
- **14 articles appli** (`misc_*` + `poumtchak`) : `misc_groove`, `misc_pattern`, `misc_sons`, `misc_notations`, `misc_tempo`, `misc_transformations`, `misc_familles`, `misc_metro`, `misc_signature`, `misc_temps_musical`, `misc_mesure`, `misc_step`, `misc_visualisation`, `poumtchak`
- **3 templates** : `concept`, `groove`, `vide` → à remplacer par code en dur dans la fonction de création

**Plan de migration** :
1. Garder `const ENCYCLO` comme fallback offline (chargé dans `packCours.encyclo` au démarrage)
2. SQL `INSERT INTO encyclo` pour les 34 articles + Lamberio exécute
3. Supprimer `ENCYCLO_MISC` et unifier avec `packCours.encycloIndex`
4. Les articles DB écrasent le fallback JS à la sync (déjà en place)

### 2. Patterns par défaut (`PTK_DEFAULT.patterns`)
Idem — fallback offline ok, mais la DB fait référence.

### 3. Sons (`SOUND_DEFS`) — **hors scope** (délibérément hard-codés)

---

## CHANTIER SUIVANT — v3.24 : Volet Band en bottom-sheet

### Objectif
Migrer le volet Band de son paradigme "volet empilé" vers un **bottom-sheet** sur le modèle de Métronome et Encyclopédie :
- Activé par le nav-tab Band → slide-up depuis le bas (même animation que metro-panel)
- Hauteur réglable par drag de la poignée
- Fermeture par bouton ✕ dans le bandeau ou drag vers le bas

### Architecture cible

```
band-panel (position:fixed, bottom:60px, z-index:103)
├── band-panel-handle-wrap (drag pour resize)
├── band-fixed-header
│   ├── bandeau : ⚙ | [◀ preset-name ▶] | 💾 | ✕
│   └── onglets éventuels (à définir — ex: "Sons" | "Ensemble")
└── band-panel-content
    ├── 3 lignes layer (son par layer — sélecteur + volume + paramètres)
    └── contrôles globaux (volume groove, mute)
```

### Points à trancher avec Lamberio avant de coder
1. **Onglets ou pas ?** — Un seul panneau Band avec tout, ou deux onglets (ex: "Sons" | "Bande") ?
2. **Coexistence avec l'actuel `band-section`** — Supprimer complètement l'ancien volet ou garder temporairement en ghost pour compat JS ?
3. **Bouton d'ouverture** — Le nav-tab Band suffit-il, ou faut-il aussi un bouton dans la RIB (PatternInfoLine) ?
4. **Hauteur minimale** — Quelle hauteur utile ? (3 lignes layer + contrôles ≈ 40-50vh ?)

### Éléments de l'actuel volet Band à conserver
- `.band-instr-btn` / `buildBandSection` — logique d'affichage des presets son
- Gestion mute par layer (`state[li].muted`)
- Volume global (`bandVolume`)
- Modal preset son (`openPresetModal({type:'sound'})`)
- CRUD sons TX/MX déjà implémenté (sections Soumettre/Publier)

### Rédaction articles encyclopédie (chantier parallèle — non bloquant)
La rédaction des 18 articles encyclopédie peut se faire en parallèle sur une session dédiée.
Liste complète dans la section "Encyclopédie — Cahier des charges" ci-dessous.

## Historique récent
| Version | Changements |
|---------|-------------|
| v3.28.39 | GCB splitter : 3 modes — drag ↕ = split (canvas setup différé à la détection), drag ↔ sur zone tempo = tempo (restaure BPM), tap = action simulée (bouton=click, zone tempo=metro) ; pointercancel restaure canvas uniquement si mode split ; suppression click-handler redondant zone tempo |
| v3.28.38 | Gestes LCB : tap 50/50 gauche=mute / droite=fold (suppression zones VU+chevron séparées) ; drag depuis n'importe où sur le segment ; GCB : suppression early-return boutons+tempo-zone → tout drag = splitter, tout tap = action simulée ; tap zone tempo → `setNavSection('metro')` |
| v3.28.37 | `_drawTotemCircle` : copie exacte de `drawCircles()` mode Pattern — aiguille dégradé couleur layer (`createLinearGradient`, midF/midA par layer index), contour blanc `rgba(255,255,255,0.82)` sur step courant, `frac` toujours calculé même à l'arrêt |
| v3.28.36 | Totem circles : aiguille de lecture (`playing` → frac → angle) dans `_drawTotemCircle`, `_updateTotemCircles()` appelé dans `visualLoop` et `visualLoopCircle` ; GCB BPM label : opacity .5→.85, weight 600→700 ; LCB overlay : "Densité"/"Longueur du pattern" en gras opacity .9, "division …" opacity .35 (plus discret) |
| v3.28.35 | Vue Totems : 3 cercles toujours visibles (suppression @container) ; `_drawTotemCircle(cv,li)` rendu identique à `drawCircles()` mode Pattern (CIRCLE_COLORS, track ring, dotR proportionnel, isMuted) ; GCB : layout grid `1fr auto 1fr` (`.gcb-left-group`/`.gcb-right-group`) → play centré exact ; `.gcb-play-btn` rectangle arrondi `border-radius:12px` pleine hauteur `align-self:stretch` |
| v3.28.34 | Vue Totems : cercle pattern déplacé sous les pads et boutons ; GCB tempo : `♩=` discret (opacity .5, 10px, weight 400) + valeur `105` en gras (16px, weight 800) via `rib-tempo-sym`/`rib-tempo-num` ; GCB : sig-btn `flex:0 0 auto` (zone de tap réduite à gauche), rib-son-btn `min-width:44px` (zone élargie) |
| v3.28.33 | 3 améliorations UI : icône 🥁 dans nav-tab Sons (était 🔊) ; GCB tempo : label « BPM » + jauge tempo plus haute (4px) + texte 13px ; Vue Totems : cercle pattern par layer (`_drawTotemCircle`, canvas `totem-circ-{li}`) visible via `@container (min-width:140px)` quand 1 ou 2 totems affichés |
| v3.28.32 | Fix splitter GCB en vue Pas et Cycle : `_sH0===0` (circle-view caché) → pas de `height:0` corrompu, pointermove no-op sans overlay trompeur, pointerup restaure `data-split` sans `_applySplit` ; CSS `flex:0 0 100%→auto` sur circle-view en cycle-linéaire desktop (flex-basis % ignorait la hauteur inline) |
| v3.28.31 | CycleInfoLine : lci-cycle aligne sa largeur sur lcb-hamburger (rAF) → colonnes LCI/LCB alignées ; cellules [data-li=0] à droite, [1] centrée, [2] à gauche ; volet Tic-Tac : bouton On/Off synced à l'ouverture (fix premier open), rouge texte+bord quand Off ; Signature + Swing labels vert léger ; advisor modal : « a priori » dans intro, avertissement polymétrie si aucune signature n'aligne tous les layers sur mesure entière |
| v3.28.30 | Advisor : signal GCB `≈` activé uniquement si score actuel < 2/3 du max (< 4.0 pour 3 layers) ET meilleure option existe (+1.0 min) — supprime les faux positifs sur signatures équivalentes ; modal filtré à `score >= max(0.3, best-2.0)` + max 6 propositions (resserrement de plage) |
| v3.28.29 | Advisor métrique : `_SIG_CANDIDATES` canonique 14 signatures (2/4→12/8) remplace `metroPresets` — scoring correct pour aksak (equiv=1) et composé ; metro col-metric : titre "Signature" en gris (`.metro-metric-lbl`), fraction dans `.metro-sig-mid` (flex:1, centrage vertical), bouton Assistance sous la fraction |
| v3.28.28 | Advisor métrique : déduplique par `id` (plus un seul N/M par combinaison, supprime doublons preset) ; overlays LCB : 1re ligne discrète "Densité" (vertical) / "Longueur du pattern" (horizontal) ; geste LCB : `DRAG_THRESH` 8→6px, ratio vert/horiz 2.5→1.5 (horizontal plus facile, vertical toujours prioritaire) |
| v3.28.27 | Assistance métrique — refonte UX : bouton signature GCB ouvre directement le modal advisor ; `≈` devient un exposant passif (`.gcb-adv-sup`) dans le texte du bouton ; volet métro : titre "SIGNATURE" + bouton "Assistance / métrique" toujours visible (opacity .5 → 1 si suggestion) ; debounce réduit 300→80 ms |
| v3.28.26 | Assistance métrique : `≈` discret dans GCB + bouton « ≈ adapter la signature » dans volet métro (colonne gauche) ; modal avec top-8 signatures scorées par alignement des patterns (mesure entière = point coloré, fraction = orange, hors-cadre = gris) ; `_advisorLayerDetail`, `_advisorScore`, `_buildSigAdvisorList`, `_openSigAdvisorModal` ; indicateur `has-suggestion` déclenché si une signature dépasse le score courant de +0.4 |
| v3.28.25 | Fix canvas touch/click double-enregistrement : `setupCanvasInteraction` s'enregistrait à chaque changement de vue via `_applyView` → step toggleé deux fois (revient à l'état initial) ; guard `cv._interactionBound` ajouté (listeners attachés une seule fois) |
| v3.28.24 | CycleInfoLine : suppression du label « cycle: » à gauche ; `_defaultSubdiv` : subdivision par défaut = 1 pour /8 et /16, = 2 pour /4 et /2 ; ligne 3441 : détection mesure composée découplée de `_defaultSubdiv` (6/8, 9/8 conservent `equiv=3`) |
| v3.28.23 | LCB drag densité ↔ : aimantation non-linéaire sur valeurs musicales — `_lcbSpm`, `_lcbSnapW`, `_lcbBuildSnapMap`, `_lcbDensN` (mesures entières 1-4 = poids 5, mesures ≥5 = 3, demi-mesure = 2.5, quart = 1.5, huitième = 1.1, non-musical = 0.55 ; carte cumulée construite au pointerdown) |
| v3.28.22 | Fix bug groove embarqué : `applyGroove`/`_applyPendingGroove` → `state[li].patternId=null` quand `gl.sequence` présent (plus de faux `i` encyclopédie vers pattern A) ; overlay densité ↔ : valeurs `n tps` / `p mes` colorées sans `=`, via `_lciDurParts(li)` ; overlay grain ↕ : suppression 3e ligne tps/mes ; CycleInfoLine : `cycle:` sans espace |
| v3.28.21 | Overlays drag LCB : format `"n pas [♪]"` + `"= n tps = p mes. de X/Y"` ; grain overlay : `"division ternaire/binaire ↕"` ; helper `_lciTpsMes(li)` ; totem : suppression `border-left` entre layers ; `setLayerDirty(li,true)` ajouté dans `_lcbSetGrain`, `unitSel.change`, `bTern.click` + `buildLayerCycleInfo()` propagé depuis `unitSel.change` et `bTern.click` |
| v3.28.20 | CycleInfoLine : label explicite `cycle : [val] [unit]` à l'extrême gauche (remplace `⦿`) ; CSS `.lci-grave/.lci-noise` passent de `flex:1/overflow:hidden` à `flex:0 0 auto` (plus de coupure de texte) ; `_lcbSetGrain` : ajout `buildLayerCycleInfo()` (durées LCI désormais rafraîchies après changement de grain) ; suppression du `buildLayerEditBar()` redondant (déjà appelé via `buildStepsDOM→updateStepSeqInfo`) |
| v3.28.19 | LCB drag overlay : option `{grooveOrLayers:true}` centre l'overlay dans `#circle-view` (si h>100px) ou `#layers-wrap` ; grain drag : ordre binaire-d'abord si pattern binaire, ternaire-d'abord si ternaire (ladder dynamique calculé au pointerdown) |
| v3.28.18 | CycleInfoLine vue mesure : arc de cercle proportionnel à la longueur du pattern (`L/stepsPerMeasure`) avec animation par tour (380ms/tour), reste affiché sur le remainder au maintien |
| v3.28.17 | CycleInfoLine : surbrillance au press via `_lciFlashLi`/`_lciStartFlash`/`_lciStopFlash` (infrastructure indépendante de `_mesureRightFlash`) — fonctionne dans toutes les vues canvas (cercle mesure, cercle motif, linéaire cycle) ; arc coloré sur l'orbite du layer (vues cercle) + bande colorée sur le 1er cycle (vue linéaire) |
| v3.28.16 | Bordure jaune déplacée sous la CycleInfoLine (pas sous la LCB) ; espace LCB↔CycleInfoLine réduit ; `.lci-cell` cliquable (`pointer-events` + `cursor:pointer` + `data-li`) ; surbrillance maintenu en vue linéaire via `_mesureRightFlash` dans `drawLinear()` |
| v3.28.15 | Fix durée `buildLayerCycleInfo._fmtSplit` mode 'mes' : formule `rawN=num×fbs×2` / `rawD=den×nbDiv×(16/beatUnit)` (base = dénominateur de signature, pas la battue) — 14 pas sur 7/4 ♩. affiche correctement « 1 mes. » |
| v3.27.14 | Fix métro : `_applyDenUnit` utilisait `_naturalBeatTimeUnit` (hors portée → `natFbs=2` toujours) → remplacé par `_applyDefaultsFromUnit()` globale ; la battue par défaut est maintenant correctement recalculée au changement de dénominateur |
| v3.27.13 | Métro : fix taille dénominateur (`font-size:26px` explicite dans `button.metro-frac-d`, `font:inherit` écrasait la classe) + centrage vertical signature (`justify-content:center` sur `.metro-col-metric`) |
| v3.27.12 | Métro : dénominateur avec flèches `< >` + label « Unité » en dessous + même taille que numérateur ; tap sur le chiffre → picker toujours actif ; `mpv-den-down/up` cyclent 2/4/8/16 |
| v3.27.11 | Métro : dénominateur de signature cliquable → popup `#sig-den-picker` avec 4 figures de notes + chiffre correspondant (suppression doublon chiffre + figure séparée) ; CLAUDE.md : section architecture Vue Totems complète |
| v3.27.10 | Totems : preview constellation circulaire (dots absolus positionnés en cercle, forte = halo double couleur layer) ; CLAUDE.md section totems |
| v3.27.9 | Totems : mini-preview visible dans les pads + verrou 🔒 calage pur (pad B gelé, seul le calage évolue en delta) |
| v3.27.8 | Totems : pads A+B couplés via `_applyTotemAB(li)` (génération squelette + calage en une passe, snapshot pré-rotation dans `_totemPreRotPat`) |
| v3.26.29 | LCB : bordure haute = visible/caché layer (`:not(.seg-folded)`) |
| v3.26.28 | LCB : bordure haute colorée quand layer ON (`not.seg-muted`) → corrigé v3.26.29 ; pastilles VU transport : `body.playing` → scale(.55)/opac:.38 repos, `.lcb-vu-soft` scale(1.25), `.lcb-vu-hit` scale(1.7) ; `refreshTransportBtn` toggle `body.playing` |
| v3.26.27 | GCB : early-return `button` dans `pointerdown` → fix double togglePlay (stop=reset+play) + fix click métronome bloqué ; LCB : `.lcb-vu-zone` zone mute = taille chevron ; bordure gauche `.seg-open:not(.seg-folded)` ; suppression border-top sur pliage |
| v3.26.26 | LCB : bordures top/left via CSS var `--lc` ; `.lcb-vu-zone` ; `.lcb-vu-soft`/`.lcb-vu-hit` soft vs accent ; `_layerDetailVisible=[false,false,false]` défaut (visible+replié) ; ordre mod-panel(5)/iso-row(10) dans flex layer ; diagonal `::after` sur VU muted |
| v3.26.25 | Design : `.layer{border-left:3px solid var(--cc)}` ; `.layer-name-btn` sans barre latérale + `color:var(--cb)` ; `.btn-pat-reset{color:var(--cb)}` |
| v3.26.24 | GCB+LCB double-barre unifiée : `gcb-play-btn` cerclé doré élevé ; `buildLCB` style `--lc:${col}` ; segments LCB avec états open/folded/muted visuels |
| v3.26.23 | Bouton ▦ toggle iso-step dans strip-1 (off par défaut, `_isoRowVisible[li]`) ; `detail-hidden` piloté par `_layerDetailVisible[li]&&_isoRowVisible[li]` |
| v3.26.22 | Sync LCB→strip-1 bidirectionnelle : `unitSel.value` + `bTern.classList` mis à jour depuis `_lcbSetGrain()` ; `_lcbUpdateSeg()` depuis `unitSel.change` et `bTern.click` |
| v3.26.21 | Fix LCB grain drag : `_lcbSetGrain` appelle `_lcbUpdateSeg` (pas `buildLCB`) pendant le drag pour éviter destruction du pointer capture ; sync strip-1 depuis LCB |
| v3.26.20 | Fix sync iso depuis canvas click : `onPt()` met à jour `.iso-cell[data-iso-idx]` (classList iso-on/iso-soft) après modification du pattern ; `buildLCB()` dans `_reszMark` |
| v3.26.19 | Fix X forts invisibles dark mode : `.iso-cell.iso-on` garde `var(--cc)` en dark mode ; iso row intégrée dans step-seq (`_moveRow2ToStepView` ne déplace pas row3) |
| v3.26.18 | Tête de lecture iso (`iso-cur`) dans `visualLoop` et `visualLoopCircle` ; fix cellules stale vue circulaire (clearCanvas avant draw) |
| v3.26.17 | Design iso cells : `border-radius:5px`, fond `rgba(38,38,45,.15)` (dark bg), `cursor:pointer`, click → cycle `.`/`X`/`x` → `buildStepsDOM` + `_buildIsoRow` ; strip-1 assemblé dans `modPanel` |
| v3.26.12–16 | Fixes itératifs splitter (drag libre sans snap, reset `_sY0` à détection, zoom `s=h/_physH`), LCB (rebuild propre après pointerup, `_lcbFolded`, `_lcbApplyFold`), GCB (gcb-handle, gcb-row, classes CSS splitter A/B/C) |
| v3.26.11 | Phase 3 Vue Édition : preset bar par layer [◀][nom][▶][💾][↺][i][🎲][⏺][✎] ; row3 iso-métrique (cellules flex ∝ durée + tête de lecture dans visualLoop) ; `_layerDetailVisible[li]` pour toggle ✎ ; `_buildIsoRow(li)` sync sur patSelect/buildStepsDOM/stepClick |
| v3.26.10 | Splitter libre — suppression `_avail()/_availCache`, reset `_sY0` à la détection du drag (zéro saut), zoom canvas libre `s=h/_physH` (s>1 autorisé), zéro snap |
| v3.26.1–9 | Phase 1 GCB (⏱·tempo·▶·sig·🔊) + Phase 2 LCB (3 segments VU/mute/grain/fold, toggle ☰/▥) + fixes splitter itératifs (état C, direction, snap, zoom) |
| v3.25.20 | Maquette it.6 — dernier tour : suppression ◀t/t▶ (redondants axe X combiné) ; WYSIWYH step manuel → inferAxesFromPat (dens/fill sync, calS/calB/geom préservés) ; suppression bouton v25/v26, mix fixe = 1re ligne v3.25 + cells v3.26 ; icône 👁 → ✎ (édition détail) |
| v3.25.19 | Maquette it.5 (retours Lamberio) : axe X pad Placement = s et b imbriqués (idx=calS·BEATS+calB, entre 2 crans s → BEATS valeurs b) ; fond padB zones alternées par cran s ; overlay pad affiche s/b/r ; axes préservés au changement de grain (calS recalé) ; suppression texte explicatif sous LCB |
| v3.25.18 | Maquette it.4 (retours Lamberio) : GCB = ⏱·tempo·▶·sig·🔊 (play centré) ; segments LCB [pastille][nb pas][unité][gros chevron] ; 🎲 = random preset ; nb pas·unité retirés de la barre layer ; boutons 👁 détail + v25/v26 à gauche de la LCB ; pads réorganisés Densité (accents↔·liant↕) / Placement (décalage↔·géo↕) ; décalage fort (intra-temps, pad X) vs faible (par temps, ◀t t▶) — formalisation r=b·spb+s |
| v3.25.17 | Maquette it.3 (retours Lamberio) : toggle ☰/▥ sur la LCB ; pastilles VU/mute dans les segments LCB (proposition correspondance 1:1) — GCB = ▶ ⏱ tempo 🔊 ; mute = état désactivé (segment+couches) ; pads densité↔/géo↕ et liant↔/calage↕ (densité en X partout) ; labels d'axes texte sans icônes ; pas d'overlay sur les totems ; totem plié masqué (les autres s'élargissent) ; boutons vue classic = presets+💾+🎲+i+⏺+↺ |
| v3.25.16 | Maquette it.2 (retours Lamberio) : Play dans GCB ; LCB sans calage (↔ densité à l'essai) ; vue lignes avec presets ◀▶ + 🎲 + i + ↺ + tête de lecture ; totems 2 pads (squelette densité↕·géo↔ / chair liant↕·calage↔) + 🎲pos/🎲acc ; mini-anneaux seulement en état C ; vue "mesure iso-métrique" notée candidate 5e vue |
| v3.25.15 | Maquette jetable `maquette_v326.html` (GlobalControlBar séparatrice + splitter 3 états, LayerControlBar grain/rotation, totems 4 axes, audio synthèse) ; décisions UX v3.26 actées dans CLAUDE.md |
| v3.23.17 | Overlay Sons restauré sur `rib-son-btn` (700ms) ; durée overlay Métronome réduite 1300→700ms ; scroll page bloqué dans tous les volets fixes (`touch-action:none` + `overscroll-behavior:contain` + handler `touchmove:preventDefault`) ; clôture session 2026-06-10 |
| v3.23.16 | Toprow Battue 3 colonnes égales (`flex:1`) centrées ; jauge vol 90% de colonne ; « Subdivision » en entier ; metro-off → vol+subdiv inactifs ; bouton ✕ déplacé du handle vers bandeau (même ligne preset) |
| v3.23.15 | Tap overlay masqué au lancement (`_dragOverlay.hide()` dans `_tapLaunchTimer`) ; jauges accent verticales → horizontales fines (5px, sans valeur) ; phrase « Tempo établi après [select] taps » au-dessus du TAP |
| v3.23.14 | Volet Battue : jauges horizontales accent + jauge vol global ; picker BeatUnit flottant (popup sur tap `♩= ▾` dans le cadran) ; toggle accent séparé de la jauge ; `_setAccVol` sync `--pct` sur jauges |
| v3.23.13 | Volet Battue toprow : jauge vol horizontal + On/Off centré + Subdiv ; flèches dénominateur `/2/4/8/16` ; `_naturalBeatTimeUnit` conforme (♩→♩, blanche→♩♩, /16→♪, /8 composé→♩.) |
| v3.23.8–12 | Refonte volet Métronome en bottom-sheet deux onglets (♩= Tempo | ▣ Battue) ; cadran rotatif `metro-wheel` ; colonne signature verte (numérateur/barre/dénominateur) + chips Unité ; tap tempo avec décompte overlay |
| v3.22.0 | PatternInfoLine gauche : jauge tempo discrète (`.rib-tempo-gauge`) sous le BPM ; clôture session 2026-06-08 |
| v3.21.32 | Fix SyntaxError accolade double dans `updateRhythmInfoBar` (JS entier inopérant) |
| v3.21.31 | PatternInfoLine gauche : suppression slider, zone drag tempo (`#rib-tempo-zone`) — glissé=tempo, tap=volet métro ; tempo centré |
| v3.21.30 | Fix `#rib-son-btn` → `_applyBandMute(!bandMuted)` (nav-bar Sons + badge mis à jour) ; vue cycle : `mes. N` quand 1 seule mesure |
| v3.21.29 | PatternInfoLine droite : hamburger\|sig\|son (gauche→droite) ; hamburger carré (`align-self:stretch`, `min-width:22px`) ; `margin-top` canvas→InfoLine réduit 10px→4px |
| v3.21.28 | Fix toggle Tic-Tac nav (`temps-content.open` comme source de vérité) ; règle « un volet à la fois » (Tic-Tac↔Sons) ; `.rib-sig-btn` sans border ; hamburger moins haut |
| v3.21.27 | PatternInfoLine : bloc stylisé (border+radius+fond) ; `.rib-left` (⏱ pleine hauteur + tempo+slider) ; slider drag-only ; suppression calculs phénomènes poly |
| v3.21.26 | Fix crashs JS init : null-guards sur `btn-tempo`, `btn-vol`, `btn-jouer` (retirés du DOM en v3.21.24) |
| v3.21.25 | Fix `</div>` orphelin ; BoomTchak lettres colorées top bar ; nom+version sur même ligne |
| v3.21.24 | Top bar réduite (nom+version uniquement) ; bouton … connexion/réglages déplacé dans bottom bar |
| v3.21.23 | PatternInfoLine : centre absolu garanti (`1fr auto 1fr`) ; info alignée sous chaque layer ; overlay tempo slider ; clôture session 2026-06-07 |
| v3.17.0 | Hamburger layers visible en déplié (opacity .38 + border discret) ; clôture session 2026-05-31 |
| v3.16.88 | groove-view-bar : hamburger `position:absolute right:4px` ; `gvb-btns padding:0 28px` symétrique → chevron centré sur point vert mini-VU (W*0.5) |
| v3.16.87 | Fix séparation chevron/hamburger : `rhythm-info-wrap` → chevron ; `layers-wrap` → hamburger seul ; `setView()` : `lw` suit `layerPanelsOuverts`, `srAV` suit `layersOuverts` |
| v3.16.86 | Volet Groove : deux boutons collapse indépendants — chevron ▼/▶ (Groove.view : canvas+boutons+poly) + hamburger tri-couleur (layers-wrap) ; état `layerPanelsOuverts` |
| v3.16.85 | Hamburger tri-couleur extrême droite groove-view-bar ; `.gvb-btns` wrapper centré ; `.gvb-layers-btn` — remplacé par v3.16.86 (malentendu sur rôle chevron) |
| v3.16.84 | Modal son : ouvre sur famille du preset courant (`familles_ids[0]`) ; `_soundOnSelect` sync label iBtn 2e ligne ; ⚙ `margin-left:auto` extrême droite |
| v3.16.83 | Volet Son : vol label déplacé à gauche (width:44px, centré) ; bouton 🎲 preset aléatoire même famille ; bouton ✨ params aléatoires (pitch/atk/env → dirty) |
| v3.16.82 | iBtn état invisible précis : top border couleur layer, reste transparent/neutre |
| v3.16.81 | Boutons instrument layer 3 états (invisible/visible-replié/visible-déplié) ; `soundLayerVisible` state ; `_setIBtnStyle` ; `_savedInstrState` save/restore au chevron |
| v3.16.80 | 2e ligne volet Band corrections : boutons ouvrent sound-ctrls (pas mod-panel) ; police condensée ; colonnes extrêmes réduites ; chevron save/restore état complet |
| v3.16.79 | Fix bouton Reprendre disparu (spécificité CSS) ; 2e ligne volet Band avec 3 boutons instrument layer |
| v3.16.78 | Groove gradient plus doré ; modal Capture Effacer↔Reprendre CSS grid sans layout shift ; mini-VU respiration part de quasi 0 ; `— ou —` avant Annuler modal Save |
| v3.16.77 | Modal Save : borders/titres couleur layer — Groove/Métronome/Pattern/Instrument/Ensemble |
| v3.16.55 | Mini-VU halo vert/noise elliptique (scaleY 0.42), bleu/rouge circulaires |
| v3.16.54 | Mini-VU halo sans délai (`hr=r0*0.8+(1-t)*maxR`, t clampé [0,1]) ; suppression ctx.scale → halo circulaire ; respiration alpha 0.18–0.34 |
| v3.16.53 | Mini-VU : respiration idle restaurée (discrète) ; halo-onde elliptique via ctx.scale ; RAF permanent quand visible ; Effacer : corbeille top:5px, billes bottom:8px (dans la corbeille) |
| v3.16.52 | Mini-VU traînées horizontales → onde ; reordering bleu(0)=gauche / vert(2)=centre / rouge(1)=droite ; RAF stoppe si inactif ; `rec-mode-strip` justify-content:center (boutons Capture centrés) |
| v3.16.51 | Mini-VU pulsant : canvas `#mini-visu` (position:absolute, pointer-events:none) derrière les boutons groove-view-bar repliée ; 3 halos colorés pilotés par le scheduleur audio (`_miniVuHit[li]` via performance.now) |
| v3.16.50 | Dark mode rec-mode-btn : spécificité 1,2,1 sur règles active (fix bug état ON invisible) ; btn-rec-clear dans `.rms-center-slot` (position:absolute, alterne avec Reprendre) ; Effacer label+poubelle+pastilles empilés |
| v3.16.49 | leb-steps restauré dans buildLayerEditBar ; col4 ratios colorés supprimé de updateRhythmInfoBar (seul label phéno jaune conservé) |
| v3.16.48 | rec-mode-strip : Remplacer ON = border violet 2px, Empiler ON = border jaune 2px, OFF = gris #bbb thin ; "temps" → "tps" dans leb-cycle |
| v3.16.47 | groove-view-bar : chevron entre Mesure et Step ; barre verticale gauche jaune ; boutons 52px uniformes (Pattern/Mesure/Step/Cycle) ; btn-mod border jaune ; collapse = seul chevron visible, jaune quand replié, violet discret quand ouvert |
| v3.16.46 | Groove.view bar restructurée 2 lignes → 1 ligne, boutons violet uniforme |
| v3.16.45 | Fix step-seq stale inline style (_applyView remet sr.style.display='') ; chevron Groove.view visible et centré |
| v3.16.0 | Redesign complet volet Métronome : 5 sous-volets avec chip teal ; Tempo = battue+BPM↕drag+Swing ; Métrique = sig+Description générée ; Métronome = boutons empilés+sig centré ; Volumes = global+3 sliders per-accent volA/volP/volp ; Tap = description+gros bouton ; `_sigDescription()` ; `playMetroClick` per-level volume |
| v3.15.33 | Modal capture : pad doux = `filter:brightness(1.4) saturate(.55)` (plus de grisé) ; sons à plein volume quand transport stoppé ; modal preset ✕ en couleur accent ; bouton ✕ fermeture ajouté au panel Encyclo ; overlay Métronome on/off + Sons on/off + labels "Tempo" / "Volume Groove" sur overlays drag ; redraw canvas au toggle Son on/off |
| v3.15.32 | Vue Step.seq : `#step-rows-wrap` reçoit `margin-left:4px; border-left:2px solid #C8961A; padding-left:6px` → ligne verticale jaune Groove continue sans interruption ; dark mode `border-left-color:#8B6914` |
| v3.15.31 | Bouton Signature top-bar → ouvre modal métro.preset avec famille "Tout" (`famFilter:'all'`) ; `#rhythm-info-bar` toujours au-dessus des layers en vue Step.seq (`order:-1`) ; marques de temps en vue Cycle/Mesure issues de `metroPattern` (positions 'A') via `_metroBeatMarks(viewMode)` |
| v3.15.30 | Correction jaune : `#layers-wrap` et `#view-mode-bar` repassent transparent (fond = canvas) ; suppression `padding:4px` sur `#layers-wrap` qui décalait la ligne verticale |
| v3.15.29 | Volet Groove franchement jaune : fond `#FFF0B3`, bordures `#C8961A`/`#E8CC60`, boutons volet/info adaptés ; dark mode `#2C2710` |
| v3.15.28 | Couleurs différenciées : Groove → jaune `#FFF0B3/#C8961A`, Métro → sarcelle `#3A8C6E` (remplace blue-steel `#5577A8`), Band → blue-steel conservé, Encyclo → gris |
| v3.15.27 | Vue circulaire : step en cours de lecture = contour blanc discret `rgba(255,255,255,0.82)` au rayon exact du point (sans halo ni agrandissement) |
| v3.15.26 | Indicateur de page mesure redessiné : nav `◀ Mes n/p ▶` en 1re ligne, infos layer `● Xmes` en dessous sans cadre ; `_mGlobalPageLast` pour hit-test en lecture ; édition sur toutes les pages |
| v3.14.50 | View bar : boutons Motif/Mesure/Pas/Cycle largeur fixe 44px, centrés, ◎/☰ à droite avec gap 10px, toujours violet ; encyclo preset bar sans max-width |
| v3.14.49 | Top bar : boutons même hauteur 30px, contrôles centrés (flex:1), BoomTchak cliquable toggle article ; view bar ◎/☰ à droite sans séparateur ; metro animation 2 temps (comme band) ; première visite : encyclo ouvre 1 seule fois (ptk_visited) |
| v3.14.48 | Top bar : icône rôle dynamique 👤/🎵/🎓/👑, version sous nom appli, hauteur +2px |
| v3.14.47 | Top bar refonte finale : BoomTchak gauche, contrôles centre, ⚙ droite, groove preset btn restauré en section bar, modal right:0 |
| v3.14.46 | Top bar : ⚙ fixe, version dans menu, sig format B (nbDivisions/beatUnit), role chip dans menu |
| v3.14.45 | Fix top bar : </div> en trop, modal left:0→left (bouton gauche), couleur groove name spécificité |
| v3.14.44 | Top bar redesign : auth icon 👤/🎓/👑, groove name centre, sig + tempo + vol droite, vue ◎/☰ dans view-mode-bar au-dessus canvas ; metro couleur blue-steel #5577A8 densité réduite |
| v3.14.43 | Metro couleur blue-steel #5577A8 (densité réduite — couleur sur états actifs/ON seulement) |
| v3.14.15 | Préférences : décalage audio → menu `<select>` sur la même ligne (6 préréglages dans l'ordre Lamberio) + slider + boutons −/+ + valeur ms seule ; `.smenu-pref-row` sépare visuellement les 5 prefs ; `.smenu-select` dark mode pour les 2 selects (métrique + décalage) |
| v3.14.14 | Audio offset : préréglages (boutons → select en v3.14.15) + −/+ ; dark mode boutons auth (sync/logout/login) ; Export MIDI → "Export MIDI…" ; `_syncMetroToGroove()` : synchro métro sur cycle groove après changement de signature pendant la lecture |
| v3.14.13 | Fix scroll modal : suppression `touch-action:none` → `e.preventDefault()` dans `pointerdown` (touch only) + simulation manuelle du clic sur `pointerup` |
| v3.14.12 | Boutons volet métro : BPM/Uni/Meter/Vol./Tap ; champ preset `sig-sel-btn` agrandi ; nouvel item inséré après la source (pas en fin de liste) ; `_sortByFamille()` pour swipe groove/pattern |
| v3.14.11 | Fix message d'erreur save preset métro (affiche message Supabase réel) ; schema.sql : `nb_divisions` dans CREATE TABLE metro_presets |
| v3.14.10 | Swipe groove/pattern : navigation dans la famille courante en premier, puis famille suivante/précédente en fin de liste |
| v3.14.9 | Fix long press modal : `setPointerCapture` déplacé dans le timer 450ms (plus dans `pointerdown`) → plus de `pointercancel` immédiat sur mobile ; même fix pour les boutons famille MX |
| v3.14.8 | Bouton ☰ Réordonner dans l'en-tête du modal preset ; fix déclenchement mute au relâcher appui long sur bouton Sons |
| v3.14.7 | Fix architecture familles : `seed_school_pool.sql` inclut `ordre` et `type` ; `PTK_DEFAULT.familles` inclut `ordre` et `type` ; migration SQL v3.14.7 (ADD COLUMN ordre/type + UPDATE familles existantes) |
| v3.14.6 | Suppression `source:'base'` metro presets → `'school'` partout ; condition seeding `metroPres.length===0` ; migration SQL UPDATE metro_presets SET source='school' WHERE source='base' |
| v3.14.5 | Suppression presets métro 6/8, 9/8, 12/8, 3/8 (statut corrompu) + migration SQL DELETE ; `_DELETED_PRESET_IDS` Set pour purge cache |
| v3.14.4 | Modal sauvegarde preset métronome unifié avec `#psp-box` (même UX que groove/pattern/band/son) ; `openMetroSavePop`, `pspDoOverwriteMetro`, `pspDoSaveNewMetro` ; dispatcher `pspDoOverwrite`/`pspDoSaveNew` étendu |
| v3.14.3 | Fix `generateMetroPattern` (non-composé : tous d>0 → 'P' pas 'p') ; fix `buildSigFromControls` (label preset conservé, pas écrasé) ; fix `_applyDefaultsFromUnit` (subdivision jamais changée) |
| v3.14.2 | Règles défaut métro.pattern : non-composé subdiv=2 (^−>−…), composé 3N/8 subdiv=1 (^>−>−…) ; `_defaultSubdiv()` ; `changeSig` réinitialise toujours le pattern ; `buildSigFromControls` préserve marques division via `_extractDivMarks`+`_rebuildPatternFromDivMarks` |
| v3.14.1 | Redesign volet Métro : boutons ^/>/− (remplace labels texte) ; layout gauche=boutons droite=subdivisions+select ; `changeSig()` reset pattern systématique |
| v3.14.0 | Refonte architecture métronome/signature : `beatsPerMeasure`→`nbDivisions`, `felBeatSteps`→`equivalence`, `stepSec=(60/spm)×(8/beatUnit)/subdivision`, `generateMetroPattern` refondu (mesures composées 6/8 9/8 12/8), `_normalizeSig()` rétrocompat, `buildSigFromControls` toujours `id:'_custom'`, migration DB v3.14.0 |
| v3.13.16 | Fix metro bug : battue-sel met maintenant à jour stepsPerBeat en même temps que felBeatSteps (sauf aksak où stepsPerBeat≠fbs intentionnel) → stepSec = beat_duration/subdivision correct |
| v3.13.15 | Revert v3.13.14 (battue-sel : BPM restait constant → SPM ne changeait pas) + corr. encyclopédie + bible §8 |
| v3.13.14 | (REVERT) Fix battue-sel incorrectement implémenté : SPM constant au lieu de BPM |
| v3.13.13 | Barre rhythmInfo 4 colonnes : _cycleInCrochesFrac, Hémiole/Polymétrie/Polyrythmie, ratio primitif, col4 par layer ; bible §8b poly |
| v3.13.7 | Fix step view IDs dupliqués dans buildLayers + _moveRow2ToStepView synchrone — MAIS problème layout step view persistant (voir BUG_STEP_VIEW ci-dessous) |
| v3.13.6 | _setupStepViewDOM() sans argument appelée à chaque setView ; 'Pas' → 'Step Sequencer' ; 'Cycle' reste 'Cycle' |
| v3.13.5 | Fix timing checkWrap (avant: avail=0 car display:none) ; _watchStepRowsWrap ResizeObserver ; _setupStepViewDOM déplace #layers-wrap après #circle-view |
| v3.13.4 | Step view : padding-bottom 10px ; step rows décalées droite (padding-left:20px) ; barre jaune étendue à #layers-wrap ; label vue en haut à droite (⊙/⊛ pour cycle) |
| v3.13.3 | Vue Pas : circle-linear en step view ; padding-bottom:0 ; ◎/☰ pour forme ; ⊙/⊛ pour cycle ; suppression label vue dans groove-bar |
| v3.13.2 | Fix vue Pas : 6 layers→3 (clear wrap avant move) ; couleurs LAYERS[li].cls sur row2 ; .btn-layer-toggle caché dans step-rows-wrap |
| v3.13.1 | Vue Pas : step rows dans #step-rows-wrap (#circle-view haut) + volets mod en bas (_moveRow2ToStepView) |
| v3.13.0 | Refactor 4 vues → 2 boutons indépendants (◎/━ forme + │/☰ cycle) + viewShape/viewCycle ; setView() réécrit |
| v3.12.30 | Fix famille order DB : sbRefreshSession() + auto-retry 401 + toasts succès/erreur |
| v3.12.29 | Poignées drag (⠿) déplacées à droite des noms familles ; drag uniquement via handle |
| v3.12.13 | Toggle ⏺ layer quand rec actif = valider les notes (stopRec true) au lieu d'annuler ; Replace = mode par défaut et encadré violet ; Overdub = discret (rec-ctrl-ovr) |
| v3.12.12 | Bouton Garder supprimé (redondant) ; Effacer → ↺ Reprendre orange : revient à originalPattern + remet hasEverTapped=false |
| v3.12.11 | Transport rec-prêt : point rouge 7px absolu (top-right) sans impact sur taille bouton ; retrait icône ⏺ du bouton Capture |
| v3.12.10 | Bouton transport rec-prêt : icône ⏺▶ via ::before (remplacé par point rouge en v3.12.11) |
| v3.12.9 | Capture forte/douce : 1 layer en rec → pouce gauche = fort (X), pouce droit = doux (x) ; sous-titres "fort"/"doux" sur les pouces ; IDs play-thumb-l-sub/r-sub |
| v3.12.8 | Transport : états arrêt/prêt-rec/lecture-rec distincts CSS (border orange / fond rouge clignotant) ; Replace encadré violet (mode le plus visible) ; article BoomTchak chargé après sbSyncPublicPool |
| v3.12.1–7 | Refonte UX Rec : bottom-bar Capture → scinde en ✗ Annuler + ✓ Valider après 1er tap ; modal rec-ctrl avec Reprendre/mode ; bouton ⏺ dans volet layer (à droite de 'i') ; couleur thumb = couleur layer ; rec-mode CSS body classes |
| v3.11.11 | Revert layout circulaire : portrait = layers sous canvas ; desktop ≥600px Pattern/Mesure = canvas gauche + layers droite ; Cycle = layers sous dans tous les cas (circle-linear class) |
| v3.11.10 | (annulé — layout côte-à-côte portrait trop étroit sur smartphone) |
| v3.11.9 | Fix bouton Capturer rouge en dark mode (spécificité CSS .active écrasait .rec-armed) ; layers sous canvas vue circle paysage (corrigé par v3.11.11) |
| v3.11.8 | Mod panel 3 cas adaptatifs via ResizeObserver : lmp-large (≥400px) 1 ligne, défaut (240–399px) 2 lignes, lmp-narrow (<240px) 3 lignes |
| v3.11.7 | Bouton ⏺ rec : même fond/bordure que btn-mod (var --cs/--cb) ; portrait rec+taille ligne 1 / clip ligne 2 ; play-drawer bordure verte/rouge selon mode |
| v3.11.6 | Rec UI : bRec cadré ⏺, Capturer rouge plein, portrait rec↑edit↓ |
| v3.11.5 | Rec phase 2 : recTap quantisé, OVR écrit direct, RPL looper (cycle boundary), _recDomUpdateLi pour rAF DOM, startRec/stopRec complets |
| v3.11.1–4 | Rec phase 1 UI : btn-rec par layer, 4 groupes mod (lecture/transf/clip/recsize), volet Jouer en rec-mode, couleur thumb = couleur layer, rec-ctrl Garder/Annuler/OVR |
| v3.10.24 | Fix modal preset : ouvre sur famille du preset courant (priorité inversée vs filtre mémorisé) ; swing overlay = %·nom ; sbMergeSchoolData inclut type famille ; sbSyncPublicPool re-applique groove courant après sync ; drawCircles clamp el<0→0 pour sync image-son au changement de groove |
| v3.10.23 | Fix volet Unit : Signature flex:0 0 auto (auto-size au contenu) ; Unité flex:0.65 ; 4 colonnes équilibrées sans débordement sur Swing |
| v3.10.22 | Volet Unit 4 colonnes : Signature + Divisions + Unité (flex:0.75) + Swing ; overlay BPM-style sur swing-slider (input → _dragOverlay.show('%') + pointerup hide) |
| v3.10.21 | Fix groove dirty au chargement : applyGroove ne propage plus bandDirty/metroDirty vers updateGrooveSaveBtn quand band_embed/metro_embed restaurés ; sliders rappel valeur : swing tap-to-reset, prefs audio offset + soft vel montrent valeur + label textuel (Synchro/Bluetooth, Doux/Fort) tap-to-reset |
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
- Contrôle : slider dans volet Unit, colonne 4 (`.metro-3col-sw`)

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

### Prochains chantiers — REC Capture + Practice (v3.11)

#### ✅ Phase 1 — REC Capture (volet Mod + volet Jouer) — implémenté v3.11.1–v3.12.13
- ⏺ Rec par layer dans volet Mod (à droite de 'i') ; visuel rouge pulsant quand `playing`
- Modes Replace (défaut, encadré violet) et Overdub (discret) ; `state[li].recMode` = 'replace' par défaut
- Quantisation : `si = round((tapTime - cycleStart) / getBeatSec(li)) % n`
- Volet Jouer en rec-mode : thumbs colorés par layer, sous-titres "fort"/"doux" (1 layer) ou nom layer (2 layers)
- Nuance forte/douce : 1 layer → pouce gauche = 'X' (fort), pouce droit = 'x' (doux/ghost)
- Bottom-bar : bouton **Capture** → après 1er tap, se scinde en **✗ Annuler** + **✓ Valider**
- Modal rec-ctrl : **↺ Reprendre** (orange, revient à originalPattern) + bouton mode Replace/Overdub
- Transport : point rouge absolu top-right quand rec-prêt ; rouge clignotant en lecture rec
- Toggle ⏺ layer quand déjà en rec → **valide** les notes capturées (ne restaure pas originalPattern)
- Clipboard : copier / coller / effacer par layer
- Mod panel adaptatif 3 cas (v3.11.8) + layout circulaire réglé (v3.11.9–v3.11.11)

#### Phase 2 — Volet Practice / Reproduction-Validation (~8–12h)
Nouveau panneau pédagogique, le plus unique de BoomTchak :
- Sélectionner un pattern de référence (école ou perso)
- Lecture en boucle du pattern de référence ; capture naturelle (non quantisée) des taps
- Comparaison step par step : écart ms par tap, représentation visuelle couleur (rouge/vert)
- Score global (% précision) après correction de l'offset systématique (calibration latence)
- Option "Garder comme pattern" avec quantisation optionnelle

**Points techniques à résoudre avant de coder :**
- Algorithme d'alignement tap↔step (distance + pénalité step manqué/tap en trop)
- Correction offset latence audio (récupérer `prefs.audioOffset` déjà en prefs)
- Mobile : timestamp iOS/Android fiables ? (performance.now vs AudioContext.currentTime)
- UX : countdown avant démarrage ? Nombre de cycles d'entraînement ?

## Résolu (session 2026-05-15 — v3.12.1–v3.12.13)
- ✅ **Refonte UX Rec** — bottom-bar : bouton Capture → scinde en ✗ Annuler + ✓ Valider après 1er tap (`body.rec-tapped`) ; modal rec-ctrl avec ↺ Reprendre (orange) + mode Replace/Overdub
- ✅ **Forte/douce** — `recTap` : 1 layer → pouce gauche = 'X', pouce droit = 'x' ; `_updateThumbColors` affiche "fort"/"doux" comme sous-titre des pouces
- ✅ **Replace = mode par défaut** — `state[li].recMode = 'replace'` ; bouton mode encadré violet en Replace, discret (rec-ctrl-ovr) en Overdub
- ✅ **Toggle ⏺ quand rec actif = valider** — `startRec` appelle `stopRec(li, true)` au lieu de `false` : les notes capturées sont gardées
- ✅ **Transport rec-états** — point rouge 7px absolu (top-right) quand rec-prêt ; rouge clignotant en lecture rec (CSS body.rec-active)
- ✅ **Article BoomTchak auto-chargé** — `showEncycloEntry('poumtchak')` après `sbSyncPublicPool` (DB fraîche)

## Résolu (session 2026-05-14 — v3.11.1–v3.11.11)
- ✅ **Bouton ⏺ Rec par layer** — volet Mod, 4 groupes (lecture / transf / clip / recsize) ; `state[li].recArmed/recording/recMode/originalPattern/recBuffer`
- ✅ **Mode OVR** — overdub : écrit 'X' directement dans `state[li].pattern`
- ✅ **Mode RPL** — looper : accumule dans `recBuffer`, applique à `si===0` (cycle boundary) ; garde le dernier cycle si aucun nouveau tap
- ✅ **recTap(tapTime)** — quantisation : `cycleStart = nextStepTime − stepPos × getBeatSec(li)` ; `si = round((tapTime − cycleStart) / bs) % n`
- ✅ **Volet Jouer en rec-mode** — bordure rouge (`play-drawer.rec-mode`), thumbs couleur layer, `_recPrevJouerOpen` restaure l'état
- ✅ **stopRec(li, validate)** — `validate=true` : garde le pattern (apply recBuffer si replace) ; `validate=false` : restaure `originalPattern`
- ✅ **Clipboard layer** — copier / coller / effacer (`patClipboard` global cross-layer)
- ✅ **Fix dark mode bouton Capturer** — règles CSS avec spécificité 0,3,0 (v3.11.9)
- ✅ **Mod panel adaptatif 3 cas** — `ResizeObserver` sur `layer-mod-panel` → classes `lmp-large` / défaut / `lmp-narrow` (v3.11.8)
- ✅ **Layout vue circulaire** — portrait : layers sous canvas ; desktop ≥600px Pattern/Mesure : canvas+layers côte à côte ; Cycle : layers sous dans tous les cas via `body.circle-linear` (v3.11.9–v3.11.11)
- ✅ **Règles de design documentées** dans `BoomTchak_v3_bible.md` (section Layout adaptatif)

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
    getFams()           → familles filtrées selon type+cfg.type (pattern→pattern+both, groove→groove+both)
    getFilteredItems()  → items filtrés (famFilter + searchQuery) ; sig : teacher en bas
    pmNewFamille()      → crée famille (type déduit depuis cfg.type ; POST DB si band/sound MX)
    pmDeleteFam(fam)    → supprime famille (school → _deletePending→Publier ; autres → local)
    pmDropFam(src,tgt)  → réordonne familles + persist DB
    pmDrop(src,tgt)     → réordonne items + persist DB
    pmAddTag / pmRemoveTag
    pmStartRename / _pmStartRenameMetroFam / _pmStartRenameFamille(nameEl,fam,table)

  Persistance ordre :
    sbPushSchoolFamOrder()      → familles école (patterns/grooves)
    sbPushSchoolMetroFamOrder() → familles métronome
    sbPushSchoolBandFamOrder()  → familles band (band_familles)
    sbPushSchoolSoundFamOrder() → familles son (sound_familles)
    sbPushSchoolOrder(type)     → items patterns/grooves
    sbPushSchoolMetroOrder()    → items metro_presets
```

---

## Encyclopédie — Cahier des charges des articles concept

### Structure d'un article (8 sections)

| # | Titre de section | Contenu |
|---|-----------------|----------|
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

### Liste des 18 articles (session 2026-05-18)
`Tempo` | `Mesure` | `Métrique` | `Mesure simple/composée` | `Mesure irrégulière` | `Temps écrit/ressenti` | `Temps` | `Temps fort/faible` | `Temps court/long` | `Temps binaire/ternaire` | `Polymétrie/Polyrythmie` | `Hémiole` | `Contretemps/Syncope` | `Pulsation/Battement` | `Division/Subdivision` | `Rythme` | `Pattern/Motif` | `Shuffle`

> Liste remplace l'ancienne (12 articles). Voir section "CHANTIER SUIVANT" pour les clés DB et détails.

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
