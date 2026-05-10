# BoomTchak v3 — Bible technique

> Document de référence : architecture, règles métier, workflows TX/MX, état DB.
> Mis à jour au fil du développement — v3.10.12

---

## 1. Architecture générale

### Principe fondamental
Application **single-file** (`index.html`) en vanilla JS, sans framework ni dépendance.
Toute la logique, les styles et le HTML sont dans ce seul fichier (~6000 lignes).

### Stack
- **Frontend** : HTML/CSS/JS vanilla (zéro dépendance)
- **Backend** : Supabase (Postgres + Auth + REST API)
- **Auth** : Google OAuth via Supabase (implicit flow, pas de SDK)
- **Persistance locale** : `localStorage` (clé `ptk_content_v2`)
- **Déploiement** : fichier statique (GitHub Pages)

### Objet central : `packCours`
Clone runtime de `PTK_DEFAULT`, stocké en localStorage. Contient :
```
packCours = {
  meta, familles, bandFamilles, bands, patterns, grooves, encyclo
}
```
- `PTK_DEFAULT` : données école hardcodées (source de vérité locale)
- `packCours` : copie modifiable, fusionnée avec Supabase au login

---

## 2. Modèle de rôles

| Rôle | Code | Description |
|------|------|-------------|
| **MX** | `'mx'` | Administrateur école. Gère le pool commun, approuve les soumissions TX. |
| **TX** | `'tx'` | Enseignant. Crée du contenu localement, le soumet à MX pour approbation. |
| **SX** | `'sx'` | Élève. Exploration et édition de ses propres patterns uniquement. |

- Rôle stocké dans `authProfile.role` (table `profiles` Supabase)
- Déterminé à l'inscription, modifiable uniquement par MX via Supabase dashboard

---

## 3. Sources de données

| `source` | Signification | Qui peut créer |
|----------|---------------|----------------|
| `'school'` | Pool commun validé (Supabase) | MX (direct) ou TX (après approbation MX) |
| `'teacher'` | Contenu personnel TX/MX non encore dans le pool | TX ou MX |
| `'pending'` | Item chargé temporairement depuis les approbations MX | MX (lecture) |

### Champ `localStatus` (items `source:'teacher'` uniquement)
| Valeur | Signification |
|--------|---------------|
| absent / `'draft'` | Modifié localement, pas encore soumis |
| `'submitted'` | Soumis à MX, en attente d'approbation |

---

## 4. Supabase — Schéma des tables

### `familles`
```
id text PK, nom text, scope ('school'|'teacher'),
owner_id uuid FK profiles, created_at,
ordre int DEFAULT 0     -- ordre d'affichage (ajouté v3.4.79)
```
Migration si table existante : `ALTER TABLE public.familles ADD COLUMN IF NOT EXISTS ordre int default 0;`
Fetch school : `?scope=eq.school&select=*&order=ordre.asc,created_at.asc`
Persistance : `sbPushSchoolFamOrder()` appelé après drag-drop dans `libDropFamille()`

### `patterns`
```
id text PK, nom text, sequence text, pas int,
familles_ids text[], encyclo_ref text,
scope ('school'|'teacher'), approved bool,
owner_id uuid FK profiles, created_at, updated_at
```

### `grooves`
```
id text PK, nom text, familles_ids text[],
band_defaut text, tempo_min int, tempo_max int, tempo_defaut int,
signature text DEFAULT '4/4',
layers jsonb,  -- [{id, patternId, mute, shift, halfOn, doubleOn}]
scope ('school'|'teacher'), approved bool,
owner_id uuid FK profiles, created_at, updated_at
```

### `encyclo`
```
key text PK, chapo text, bullets jsonb,  -- [["Titre","Texte"], ...]
scope ('school'|'teacher'), approved bool,
owner_id uuid FK profiles, updated_at
```

**Extension prévue (articles concept v3.10+)** : le champ `bullets jsonb` sera étendu ou remplacé
par `sections jsonb` pour supporter le format 8 sections nommées avec ancres (voir CLAUDE.md §Encyclopédie).
Migration à prévoir : `ALTER TABLE public.encyclo ADD COLUMN IF NOT EXISTS sections jsonb;`

### Colonnes supprimées (migration v3.1 → v3.1+)
- `patterns.unite_temps`, `patterns.pas_par_mesure`
- `grooves.vitesse_mult`

---

## 5. RLS (Row Level Security)

### Familles
- **SELECT** : école OU owner = moi OU MX
- **INSERT** : tout utilisateur authentifié
- **UPDATE/DELETE** : owner = moi OU MX

### Patterns & Grooves
- **SELECT** : (école ET approuvé) OU owner = moi OU MX
- **INSERT** : owner doit être moi
- **UPDATE/DELETE** : owner = moi OU MX

### Encyclopédie
- **SELECT** : école OU owner = moi OU MX
- **INSERT** : tout utilisateur authentifié
- **UPDATE** : owner = moi OU MX
- *(pas de DELETE policy — suppression non exposée)*

### Règle critique post-approbation
Lors de l'approbation par MX : `owner_id` est mis à `null`.
→ Le TX soumetteur **perd** le droit UPDATE/DELETE sur l'item une fois approuvé.
→ Seul MX peut ensuite modifier un item `scope:'school'`.

---

## 6. Matrice CRUD complète

### Légende
- ✅ Implémenté et correct
- ⚠️ Implémenté mais cas limite non couvert
- ❌ Manquant
- 🔒 Bloqué intentionnellement

---

### FAMILLES

| Opération | TX | MX | Supabase | Gaps |
|-----------|----|----|----------|------|
| Créer | ✅ local seulement | ✅ local + INSERT DB | POST /familles (upsert) | ⚠️ Famille TX jamais en DB — si TX soumet un pattern avec cette famille, l'ID est inconnu de MX |
| Renommer | ✅ local seulement | ✅ local + UPSERT DB | POST /familles | ⚠️ Même problème |
| Supprimer | ✅ local + cascade patterns/grooves | ✅ local + cascade + DELETE DB | DELETE /familles | ❌ Si TX supprime une famille utilisée par un pattern soumis → orphelin en DB |
| Réordonner | ✅ local | ✅ local | ❌ pas de colonne ordre | ❌ Ordre perdu après sync pour tous |

---

### PATTERNS

| Opération | TX | MX | Supabase | Gaps |
|-----------|----|----|----------|------|
| Créer | ✅ local, source:'teacher' | ✅ local, source:'teacher' | ❌ pas de push auto | — |
| Renommer | ✅ local | ✅ local | ❌ | ⚠️ Si soumis : nom en DB obsolète jusqu'à re-soumission |
| Supprimer (perso) | ✅ local si non utilisé | ✅ local | ❌ | ❌ Si soumis : orphelin en DB (TX devrait annuler avant supprimer) |
| Supprimer (école) | 🔒 interdit TX | ❌ pas d'UI MX | DELETE possible via RLS | ❌ Aucun bouton MX pour supprimer un item école |
| Éditer séquence | ✅ local → publish | ✅ local → publish | via publish | ⚠️ TX peut éditer un item école localement, mais source reste 'school' → jamais soumis |
| Assigner famille | ✅ local | ✅ local | inclus dans publish | ⚠️ Changement post-soumission nécessite re-soumission manuelle |
| **Soumettre (TX→MX)** | ✅ POST scope='teacher', approved=false, localStatus='submitted' | — | ✅ | — |
| **Approuver (MX)** | — | ✅ PATCH scope='school', approved=true, owner_id=null | ✅ | — |
| **Rejeter (MX)** | — | ✅ DELETE row | ✅ | ⚠️ TX ne sait pas pourquoi (pas de message de refus) |
| **Annuler soumission (TX)** | ✅ DELETE row + reset localStatus | — | ✅ | — |
| **Feedback refus → TX** | ✅ sbCheckRejections au sync → toast | — | ✅ (indirecte) | — |
| Réordonner | ✅ local | ✅ local | ❌ | ❌ Ordre non persisté |
| Modifier item école | ⚠️ local seulement, jamais soumettable | ✅ via re-publish | — | ❌ Pas de mécanisme "fork" |

---

### GROOVES

*Mêmes règles que Patterns pour créer/renommer/supprimer/soumettre/approuver/rejeter.*

| Opération spécifique | État | Gap |
|----------------------|------|-----|
| Éditer layers (mute/half/double/shift) | ✅ temps réel → dirty flag → saveGroove() → local | — |
| Changer le pattern d'une couche | ✅ même workflow (TX et MX) | — |
| Changer de groove **en cours de lecture** | ✅ resync sur le prochain temps 1 du métronome (v3.4.47) | — |
| Éditer tempo (min/max/défaut) | ❌ non exposé post-création | ❌ Tempo figé après création |
| Éditer signature | ❌ non exposé post-création | ❌ Signature figée après création |

#### Détail : `applyGroove` et `patternId` de couche (correctif v3.4.32)

Problème antérieur : si `getPattern(gl.patternId)` retournait `null` (pattern pas encore chargé),
`applyGroove` faisait un `return` prématuré **sans** avoir mis à jour `state[li].patternId`.
→ `saveGroove()` réutilisait le `patternId` du groove précédent → mauvais pattern sauvé.

Fix (3 points) :
1. `applyGroove` : `state[li].patternId = gl.patternId` **avant** l'early return
2. `buildLayers` : initialisation du select priorise `state[li].patternId` sur `findPatternBySeq`
3. Handler changement de pattern : étendu à tous modes (était TX-only → MX exclu)

---

### ENCYCLOPÉDIE

| Opération | TX | MX | Supabase | Gaps |
|-----------|----|----|----------|------|
| Initialisation | ✅ clone ENCYCLO JS au 1er edit | ✅ | — | — |
| Éditer chapo | ✅ local (contentEditable + blur) | ✅ local | ❌ | ❌ Jamais poussé en DB |
| Éditer bullets | ✅ local | ✅ local | ❌ | ❌ Idem |
| Sauvegarder | ✅ localStorage | ✅ | ❌ | — |
| Vider une entrée | ✅ local (vide, ne supprime pas) | ✅ | ❌ | — |
| Soumettre à MX | ❌ non implémenté | — | — | ❌ Pas de workflow TX→MX |
| Publier en DB (MX) | — | ❌ non implémenté | — | ❌ Pas de bouton MX "Sauvegarder en DB" |
| Sync depuis DB | ✅ sbMergeSchoolData au login | ✅ | ✅ (seedé) | ⚠️ Éditions locales écrasent DB si sync avant édition |

**Décision de design** : l'encyclopédie est un contenu éditorial MX-only.
Le workflow naturel est : MX édite → MX publie en DB → tous les TX reçoivent au sync suivant.
Les éditions TX restent locales (annotations personnelles).

**Évolution v3.10+ — Articles concept** : 12 articles pédagogiques (Tempo, Mesure, Temps, Pulsation,
Division, Rythme, Pattern, Groove, Syncope, Polymétrie, Shuffle, Cycle) au format 8 sections nommées
(En bref / En théorie / En pratique / Dans BoomTchak / Pour aller plus loin / Histoire-Culture /
Voir aussi). Structure et cahier des charges complets dans CLAUDE.md §Encyclopédie.

---

## 7. Workflows complets

### Workflow A — TX crée et soumet un pattern/groove
```
1. TX crée localement (source:'teacher', pas de push DB)
2. TX édite, nomme, assigne familles → tout local
3. TX ouvre ···  → Soumettre → clique "→ Envoyer"
   → POST /patterns avec scope='teacher', approved=false
   → localStatus = 'submitted' (bouton devient ⏳ En attente)
4. MX reçoit notification (badge ···) → section Approbations
5a. MX approuve → PATCH scope='school', approved=true, owner_id=null
    → item devient école pour tous au prochain sync TX
5b. MX rejette → DELETE row
    → au prochain sync TX : sbCheckRejections détecte l'absence
    → localStatus reset à 'draft' + toast "N soumission(s) refusée(s)"
```

### Workflow B — TX annule sa soumission
```
1. TX voit ⏳ En attente dans ···  → Soumettre
2. TX clique ✕ Annuler
   → DELETE /patterns?id=eq.{id}
   → localStatus supprimé, item repasse en draft (→ Envoyer)
```

### Workflow C — MX crée et publie directement
```
1. MX crée localement (source:'teacher')
2. MX clique "↑ Publier" → "↑ École"
   → POST avec scope='school', approved=true
   → source local passe à 'school'
   → disponible pour tous au prochain sync
```

### Workflow D — Sync école (login ou bouton ↻)
```
1. Fetch parallel : patterns + grooves + familles + encyclo (scope='school', approved=true)
2. sbMergeSchoolData : remplace les items école locaux par les données DB
3. sbCheckRejections (TX uniquement) : détecte les soumissions refusées
4. saveToStorage() + render()
```

### Workflow E — Familles MX
```
Créer  → local push + sbSaveFamille (POST upsert Supabase)
Renommer → local edit + sbSaveFamille (POST upsert Supabase)
Supprimer → local cascade + sbDeleteFamille (DELETE Supabase)
TX crée → local seulement (jamais en Supabase)
```

---

## 8. Architecture tempo — SPM vs BPM (ajouté v3.4.33)

### Principe
Le slider `#bpm` (id historique) stocke des **SPM** (Steps Per Minute = vitesse de la croche ♪).
Le **BPM** musical est une valeur **dérivée** et affichée uniquement :

```
BPM = SPM / currentSig.stepsPerBeat
```

### `SIGNATURES` — champ `stepsPerBeat`
| Signature | stepsPerBeat | Exemple |
|-----------|--------------|---------|
| 4/4, 2/4, 3/4 | 2 | ♩ = SPM/2 |
| 6/8, 9/8, 12/8 | 3 | ♩. = SPM/3 |
| 2/2 | 4 | 𝅗𝅥 = SPM/4 |

### Affichage barre tempo
- `#beat-display` : BPM musical (`♩= 104`)
- `#spm-display` : SPM brut (`♪208`)

### Préférence `sigChangeLock` (localStorage `btk_prefs`)
| Valeur | Comportement sur changement de métrique |
|--------|----------------------------------------|
| `'spm'` | SPM constant — BPM change (croche garde sa vitesse) |
| `'bpm'` | BPM constant — recalcule SPM = `oldBPM × newSig.stepsPerBeat` |

Défaut : `'bpm'` (musicalement correct — la pulsation reste stable).

### Calcul dans le moteur audio
```javascript
getBeatSec(li)    = (60 / spm) / mult * ternFactor   // durée d'un step couche (avec mult et ternFactor)
getMetroBeatSec() = (60 / spm) * currentSig.stepsPerBeat  // beat métronome (sans mult ni ternFactor)
```
où `spm` est la valeur brute du slider (Steps Per Minute).

### Resync groove sur changement en lecture (v3.4.47)
Quand `applyGroove()` est appelé pendant la lecture, toutes les couches sont réalignées sur le
**prochain temps 1** du métronome (fin de la mesure en cours) :
```javascript
const beatsLeft = (currentSig.beatsPerMeasure - metroBeatPos) % currentSig.beatsPerMeasure;
const syncTime  = Math.max(now, metroNextBeatTime + beatsLeft * beatSec);
LAYERS.forEach((_, li) => {
  state[li].stepPos = 0;
  state[li].nextStepTime = syncTime;
  state[li].startTime    = syncTime;
});
```
→ Garantit que le nouveau groove repart toujours au début d'une mesure, en phase avec le métronome.

---

## 9. Architecture vue circulaire (ajoutée v3.4.36)

### Modes de visualisation
| Mode | Variable | Description |
|------|----------|-------------|
| `'measure'` (défaut) | `circleModeView` | 1 tour de cercle = 1 mesure complète |
| `'cycle'` | `circleModeView` | 1 tour de cercle = 1 cycle du pattern |

Bouton toggle `↺ Pattern` / `↺ Mesure` affiché au-dessus du canvas `#rhythm-canvas`.

### Mode Mesure — formules clés
```
measureSec = (60/spm) * stepsPerBeat * beatsPerMeasure
patternSec = getBeatSec(li) * n           // durée d'un cycle du pattern
maxRep     = Math.ceil(measureSec / patternSec)   // occurrences du pattern dans 1 mesure
```

Angle du step `si` à la répétition `rep` :
```
frac  = (si + rep * n) * getBeatSec(li) / measureSec
angle = -Math.PI/2 + 2*Math.PI*frac
```

### Occurrences répétées ("ghost steps")
Quand un pattern est plus court qu'une mesure (`maxRep > 1`), ses steps sont dupliqués pour remplir
le cercle. Les occurrences répétées (rep > 0) ont un visuel distinct :
- **Taille totale identique** aux steps normaux (rayon `dotR`)
- **Fill** : disque intérieur de rayon `dotR * 0.62` → laisse un anneau vide sur le bord extérieur
- **Stroke** : cercle plein à `dotR`

### Occurrence active (anneau "playing")
```
posInMeasure = ((elapsedSinceStart % measureSec) + measureSec) % measureSec
currentRepM  = Math.min(Math.floor(posInMeasure / patternSec), maxRep - 1)
```
L'anneau de lecture n'est dessiné que pour `rep === currentRepM`.

### Niveaux de visibilité des steps
| Contexte | Step accentué (on) | Step faible (soft) | Step off |
|----------|--------------------|--------------------|----------|
| Vue linéaire | 100 % | 40 % (`--cm`, hex `66`) | invisible |
| Vue circulaire | 100 % | 60 % (hex `99`) | invisible |

Les steps soft n'ont **pas** de bordure colorée en vue linéaire (`border-color: var(--cs)`).

### Rafraîchissement automatique
`buildStepsDOM(li, wrap)` appelle `if(circleView) drawCircles()` en dernière instruction.
Couvre : chargement de pattern ou groove, tous les boutons mod (rotate, accent, length…), mute,
et changement de signature.

---

## 10. Familles multi-axes — Concept futur (noté v3.4.35)

### Problème actuel
Les familles sont une liste plate partagée par tous les types d'items → liste longue, peu discriminante.

### Solution envisagée
Tags multi-axes AND-filtrables :
- Axes : `style`, `metrique`, `feeling`, `difficulte`, `pedagogue`
- Chaque famille appartient à un axe (champ `category` déjà présent en DB)
- Un item peut avoir plusieurs tags de différents axes
- Filtre : sélection AND inter-axes (chip-based UI)

### À décider avant implémentation
- Standardisation des valeurs de `category` en DB
- Champ `scope` (types d'items compatibles) : optionnel ou obligatoire ?
- Migration des données existantes

**Status : à mettre en chantier après validation archi avec Lamberio.**

---

## 11. Chantier futur — Metro comme pattern (noté v3.4.49)

### Problème actuel
Les signatures asymétriques (7/8, 11/8, 13/8…) ont des **regroupements internes variables** selon le style
musical (Rachenitsa 7/8 = 3+2+2 ; Daichovo 9/8 = 2+2+2+3…). L'architecture actuelle ne peut encoder
que des séparateurs réguliers (toutes les N croches), sans distinctions d'accent ni de regroupement.

### Concept
Remplacer les signatures hardcodées par des **presets de métronome** où les coups sont encodés
comme un mini-pattern, à l'image des patterns de grooves.

### Structure envisagée
```javascript
{
  id: '7/8_rachenitsa',
  nom: 'Rachenitsa (3+2+2)',
  totalSteps: 7,           // nombre de croches par mesure
  stepsPerBeat: 1,         // unité interne (croche = 1 step)
  // Niveau de chaque step : 'A' accent fort (temps 1), 'P' accent de groupe, 'p' pulse léger, '·' silence
  metroPattern: ['A','p','p','P','p','P','p']
}
```

### Impact architectural
- Refonte de `SIGNATURES` → `METRO_PRESETS`
- Refonte du scheduler métronome (volume par level plutôt que position % beatsPerMeasure)
- Refonte de `buildStepsDOM` : séparateurs aux positions 'A' et 'P' (regroupements)
- Interface de création/édition de presets (futur)

### Prérequis
Valider le modèle avec Lamberio avant tout codage.

---

## 12. Règle de déploiement (ajoutée v3.2.1)

**Le développeur (Claude) doit, après chaque push de branche feature :**
1. Créer une PR draft si elle n'existe pas encore
2. Merger la PR vers `main` (fast-forward ou merge commit)
3. Vérifier que `main` est à jour sur `origin`

→ L'utilisateur peut ainsi tester directement depuis GitHub Pages sans action manuelle.
→ Cette règle est inscrite dans `CLAUDE.md`.

---

## 13. Gaps identifiés — Backlog priorisé

### Résolu ✅ (vérifié session 2026-04-28)
| # | Description | Localisation |
|---|-------------|--------------|
| G0 | **Bug initAuth() bloquant** — `authSession` vidé si `authProfile` null après `sbFetchProfile()` | ll. 5291–5296 |
| G8 | **Ordre patterns/grooves persisté** — `sbPushSchoolOrder()` appelée après drag-drop | ll. 4123–4137, 5666, 6319 |
| GAP_FAM_RENAME_TX | **Renommage TX famille** — soumission indépendante via `_pendingRename` + section "Tags familles" | ll. 5117–5126 |

### Priorité haute
| # | Description | Impact |
|---|-------------|--------|
| G1 | **Fork item école** : TX modifie un item école → copie automatique en source:'teacher' pour soumission | TX ne peut pas proposer d'amélioration d'un item école |
| G2 | **Famille TX transmise à la soumission** : push les familles TX (scope:'teacher') au moment du submit pattern/groove | MX voit des IDs de famille inconnus |
| G3 | **Suppression locale → annulation Supabase auto** : si item localStatus:'submitted', DELETE Supabase avant supprimer localement | Orphelins en DB |
| G4 | **MX → Tout sauver en DB** : patterns/grooves/encyclo/familles MX doivent pouvoir être publiés directement en école | Perte de données si localStorage vidé |

### Priorité moyenne
| # | Description | Impact |
|---|-------------|--------|
| G5 | **Encyclo MX → DB** : bouton "Publier en DB" dans la section encyclopédie pour MX | Éditions MX perdues si localStorage vidé |
| G6 | **Édition tempo/signature post-création** | Groove figé après création |
| G7 | **Raison de refus** : MX peut saisir un message lors du rejet, TX le voit dans le toast | UX de communication TX/MX |

### Priorité basse
| # | Description | Impact |
|---|-------------|--------|
| G9 | **Suppression item école depuis l'UI MX** | MX doit passer par le dashboard Supabase |
| G10 | **Historique des soumissions** | Traçabilité TX/MX |

---

## 14. Fonctions Supabase clés

| Fonction | Endpoint | Rôle |
|----------|----------|------|
| `sbSyncSchoolPool()` | GET patterns/grooves/familles/encyclo | Sync école au login/manuel |
| `sbPublishPattern(id)` | POST /patterns (upsert) | Soumission TX ou publication MX |
| `sbPublishGroove(id)` | POST /grooves (upsert) | Idem pour grooves |
| `sbApproveItem(type, id)` | PATCH → scope='school', owner_id=null | Approbation MX |
| `sbRejectItem(type, id)` | DELETE | Rejet MX |
| `sbCancelSubmission(type, id)` | DELETE | Annulation TX |
| `sbCheckRejections()` | GET patterns+grooves (owner=moi, approved=false) | Détecte les refus MX côté TX |
| `sbFetchPendingApprovals()` | GET patterns+grooves (scope='teacher', approved=false) | Liste approbations pour MX |
| `sbSaveFamille(fam)` | POST /familles (upsert) | Sauvegarde famille MX en DB |
| `sbDeleteFamille(id)` | DELETE /familles | Suppression famille MX en DB |

---

## 15. Fichiers du projet

| Fichier | Rôle |
|---------|------|
| `index.html` | Application complète (HTML + CSS + JS) |
| `BoomTchak_Explain.md` | Document de référence complet (pédagogie + UX + technique + roadmap) |
| `BoomTchak_v3_bible.md` | Ce fichier — référence technique v3 |
| `CLAUDE.md` | Instructions pour les sessions Claude Code |
| `supabase/schema.sql` | Schéma DB à exécuter sur nouvelle instance |
| `supabase/seed_school_pool.sql` | Seed complet : familles + patterns + grooves + encyclo (32 entrées) |
| `supabase/generate_encyclo_seed.js` | Script Node.js qui regénère la section encyclo du seed depuis `index.html` |
| `supabase/SETUP_GUIDE.md` | Guide de déploiement Supabase |

---

## 16. Architecture volet métronome (v3.10+)

### Sous-volets (5 boutons toggle indépendants)
| Volet | ID | Contenu |
|-------|----|---------|
| **Tempo** | `metro-sub-tempo` | 2 colonnes : BPM (slider large + −/+) + Battement (select felBeatSteps + input BPM) |
| **Unit** | `metro-sub-unit` | 3 colonnes : Divisions (sig inline + < N >) + Unité (select beatUnit) + Swing (slider MPC) |
| **Tap** | `metro-sub-tap` | Bouton tap-tempo ; calcule la moyenne des intervalles |
| **Vol** | `metro-sub-vol` | Slider volume métronome (classe `temps-slider`) |
| **Métro** | `metro-sub-pat` | ctrl-row accents (^/>/−) + select subdivision + pattern viz |

### Fonctions clés (v3.10.8+)

| Fonction | Rôle |
|----------|------|
| `computeSigLabel()` | Lit les positions 'A' dans metroPattern → génère "2+3/8" ou "4/4" |
| `updateSigDisplays()` | Synchronise `sig-unit-display` et `mpv-sig-label` via `computeSigLabel()` |
| `_applyDefaultsFromUnit()` | Auto-sync felBeatSteps et subdivision depuis l'unité sélectionnée |
| `getSwingName(mpcPct)` | Retourne le nom du style de swing pour un % MPC donné (50–75%) |
| `updateSwingDisplay()` | Synchronise `swing-display` (%) et `swing-name` (style) depuis `swingVal` |
| `syncMetroControls(sig)` | Synchronise tous les contrôles du volet depuis `currentSig` |

### Formule swing (v3.10.11)
```js
// Steps impairs d'un layer (si % 2 === 1) :
const swOff = swingVal * 0.5 * getBeatSec(li);
// Steps impairs du métro :
const swOffM = swingVal * 0.5 * (60 / spmNow);
```
Affichage MPC = `50 + swingVal × 25` % → plage 50% (straight) à 75% (dotted shuffle).

---

## 17. Historique des versions

| Version | Changements principaux |
|---------|----------------------|
| v3.0.0 | Refonte v3 : Supabase, rôles TX/MX, pool école |
| v3.1.0 | Workflow approbation, pastille ···, statuts |
| v3.2.0 | localStatus draft/submitted, bouton Annuler TX, bouton Rejeter MX, familles MX → Supabase, correction RLS owner_id, feedback refus (toast) |
| v3.2.1 | Icône cloche bouton métronome, bump docs, règle de déploiement auto main |
| v3.4.32 | Correctif groove patternId (3 points : applyGroove, buildLayers, handler MX) |
| v3.4.33 | Double affichage BPM + SPM ; préférence sigChangeLock (SPM/BPM constant) |
| v3.4.34 | Metro pleine largeur paysage ; slider adaptatif ; sig-sel compact ; défaut sigChangeLock:'bpm' |
| v3.4.35 | Largeur sig-sel corrigée à 4.2ch (4 caractères exact, DPI-indépendant) |
| v3.4.36–37 | Vue circulaire : toggle ↺ Pattern / ↺ Mesure ; mode Mesure par défaut ; steps positionnés en fraction de mesure avec répétitions si pattern < mesure |
| v3.4.38–42 | Anneau "playing" sur l'occurrence active uniquement (currentRepM) ; visual ghost : fill 62% du rayon + anneau vide extérieur |
| v3.4.43–44 | Step soft (×) : 40 % vue linéaire sans bordure colorée ; 60 % vue circulaire |
| v3.4.45–46 | buildStepsDOM rafraîchit le cercle automatiquement (load, mods, rotation, mute, signature) |
| v3.4.47 | applyGroove : resync alignée sur le prochain temps 1 du métronome (getMetroBeatSec) |
| v3.4.48 | Encyclopédie : misc_tempo (SPM/BPM), misc_signature (sigChangeLock), misc_mesure (↺ Mesure), nouvel article misc_visualisation |
| v3.4.49 | Signatures 7/4, 7/8, 11/8, 13/8 ; encyclopédie misc_signature étendue ; chantier futur metro-comme-pattern documenté |
| v3.9.0 | Volet Band : modal type:'band' modes ✎/☰ ; TX/MX CRUD bands ; table `bands`+`band_familles` |
| v3.10.8 | Refonte volets metro Tempo/Unit/Métro ; computeSigLabel() ; updateSigDisplays() ; _applyDefaultsFromUnit() |
| v3.10.9 | Volet Unit compact (metro-3col) ; boutons < > visibles ; blanche=♩♩ ; ronde=○ |
| v3.10.10 | Vue Cycle : totalU = LCM patterns only (signature = séparateur visuel) |
| v3.10.11 | Swing MPC 50–75% : formule ×0.5×stepDuration ; getSwingName() 8 niveaux ; déplacé vers Unit |
| v3.10.12 | Signature inline gauche dans Unit (sig-edit-val neutre) ; swing colonne 3 (% + nom) |
