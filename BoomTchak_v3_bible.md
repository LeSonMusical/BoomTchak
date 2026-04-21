# BoomTchak v3 — Bible technique

> Document de référence : architecture, règles métier, workflows TX/MX, état DB.
> Mis à jour au fil du développement — v3.2.0

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
- **Déploiement** : fichier statique (GitHub Pages ou équivalent)

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
owner_id uuid FK profiles, created_at
```

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
| Changer le pattern d'une couche | ✅ même workflow | — |
| Éditer tempo (min/max/défaut) | ❌ non exposé post-création | ❌ Tempo figé après création |
| Éditer signature | ❌ non exposé post-création | ❌ Signature figée après création |

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

## 8. Gaps identifiés — Backlog priorisé

### Priorité haute
| # | Description | Impact |
|---|-------------|--------|
| G1 | **Fork item école** : TX modifie un item école → copie automatique en source:'teacher' pour soumission | TX ne peut pas proposer d'amélioration d'un item école |
| G2 | **Famille TX transmise à la soumission** : push les familles TX (scope:'teacher') au moment du submit pattern/groove | MX voit des IDs de famille inconnus |
| G3 | **Suppression locale → annulation Supabase auto** : si item localStatus:'submitted', DELETE Supabase avant supprimer localement | Orphelins en DB |

### Priorité moyenne
| # | Description | Impact |
|---|-------------|--------|
| G4 | **Encyclo MX → DB** : bouton "Publier en DB" dans la section encyclopédie pour MX | Éditions MX perdues si localStorage vidé |
| G5 | **Édition tempo/signature post-création** | Groove figé après création |
| G6 | **Raison de refus** : MX peut saisir un message lors du rejet, TX le voit dans le toast | UX de communication TX/MX |

### Priorité basse
| # | Description | Impact |
|---|-------------|--------|
| G7 | **Ordre familles persisté** : colonne `ordre int` en DB, sync à la sauvegarde MX | Ordre MX perdu après sync |
| G8 | **Suppression item école depuis l'UI MX** | MX doit passer par le dashboard Supabase |
| G9 | **Historique des soumissions** | Traçabilité TX/MX |

---

## 9. Fonctions Supabase clés

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

## 10. Fichiers du projet

| Fichier | Rôle |
|---------|------|
| `index.html` | Application complète (HTML + CSS + JS) |
| `supabase/schema.sql` | Schéma DB à exécuter sur nouvelle instance |
| `supabase/seed_school_pool.sql` | Seed complet : familles + patterns + grooves + encyclo (32 entrées) |
| `supabase/generate_encyclo_seed.js` | Script Node.js qui regénère la section encyclo du seed depuis `index.html` |
| `supabase/SETUP_GUIDE.md` | Guide de déploiement Supabase |

---

## 11. Versions

| Version | Changements principaux |
|---------|----------------------|
| v3.0.0 | Refonte v3 : Supabase, rôles TX/MX, pool école |
| v3.1.0 | Workflow approbation, pastille ···, statuts |
| v3.2.0 | localStatus draft/submitted, bouton Annuler TX, bouton Rejeter MX, familles MX → Supabase, correction RLS owner_id, feedback refus (toast) |
