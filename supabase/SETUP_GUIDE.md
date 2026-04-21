# Guide de mise en place BoomTchak V3 — Base école partagée

Ce guide vous conduit de zéro à une app opérationnelle avec login Google et synchronisation du pool école.

**Durée estimée : 30–45 minutes**  
**Prérequis : un compte Google de l'école**

---

## Étape 1 — Créer le projet Supabase

1. Aller sur **https://supabase.com** → cliquer **Start your project**
2. Se connecter avec votre compte GitHub (ou créer un compte Supabase)
3. Cliquer **New project**
4. Remplir :
   - **Name** : `boomtchak`
   - **Database Password** : choisir un mot de passe fort (le noter quelque part)
   - **Region** : `West EU (Ireland)` — proche de la France, conformité RGPD
5. Cliquer **Create new project** — attendre 1–2 minutes

---

## Étape 2 — Récupérer l'URL et la clé anon

1. Dans Supabase, aller dans **Settings** (icône engrenage en bas à gauche)
2. Cliquer **API**
3. Noter :
   - **Project URL** : `https://xxxxxxxxxxxx.supabase.co`
   - **anon public** (sous "Project API keys") : une longue chaîne de caractères
   - **service_role** (cliquer "Reveal") : à garder secrète, uniquement pour le seed

---

## Étape 3 — Exécuter le schéma SQL

1. Dans Supabase, cliquer **SQL Editor** dans le menu gauche
2. Cliquer **New query**
3. Copier-coller le contenu du fichier `supabase/schema.sql`
4. Cliquer **Run** (▶) — vous devez voir "Success. No rows returned"

---

## Étape 4 — Configurer l'authentification Google

### 4a — Créer les identifiants Google (15 min)

1. Aller sur **https://console.cloud.google.com**
2. En haut, cliquer sur le sélecteur de projet → **New Project**
   - Nom : `BoomTchak`  → **Create**
3. Dans le menu hamburger (≡), aller dans **APIs & Services** → **OAuth consent screen**
4. Choisir **External** → **Create**
5. Remplir :
   - **App name** : `BoomTchak`
   - **User support email** : votre email école
   - **Developer contact information** : votre email
6. Cliquer **Save and Continue** (3 fois, les étapes Scopes et Test users peuvent rester vides)
7. Revenir sur **APIs & Services** → **Credentials**
8. Cliquer **+ Create Credentials** → **OAuth client ID**
9. **Application type** : `Web application`
10. **Name** : `BoomTchak Web`
11. Sous **Authorized redirect URIs**, cliquer **+ Add URI** et entrer :
    ```
    https://VOTRE_ID_PROJET.supabase.co/auth/v1/callback
    ```
    *(remplacer `VOTRE_ID_PROJET` par le début de votre Project URL)*
12. Cliquer **Create**
13. Une fenêtre affiche votre **Client ID** et **Client Secret** → les noter

### 4b — Activer Google dans Supabase

1. Dans Supabase, aller dans **Authentication** → **Providers**
2. Trouver **Google** → cliquer pour dérouler
3. Activer le toggle **Enable Sign in with Google**
4. Coller le **Client ID** et **Client Secret** de l'étape précédente
5. Cliquer **Save**

### 4c — Ajouter l'URL de redirection

1. Dans Supabase, **Authentication** → **URL Configuration**
2. Sous **Redirect URLs**, cliquer **+ Add URL** et ajouter :
   ```
   https://lesonmusical.github.io/BoomTchak/
   ```
   *(et `http://localhost:8080/` pour les tests locaux)*
3. **Site URL** : `https://lesonmusical.github.io/BoomTchak/`
4. Cliquer **Save**

---

## Étape 5 — Mettre à jour index.html

Ouvrir `index.html`, trouver le MODULE SUPABASE (chercher `VOTRE_URL_SUPABASE`) et remplacer :

```javascript
const SUPABASE_URL     = 'https://XXXX.supabase.co';   // ← votre Project URL
const SUPABASE_ANON_KEY = 'eyJhbGc...';                 // ← votre clé anon public
```

---

## Étape 6 — Lancer le seed

Le seed pousse tous les patterns/grooves/familles dans la base école.

**Prérequis :** Node.js v18+ installé  
*(vérifier avec `node --version` dans un terminal)*

```bash
# Dans le dossier BoomTchak :
SUPABASE_URL="https://XXXX.supabase.co" \
SUPABASE_SERVICE_KEY="votre_service_role_key" \
node supabase/seed_school_pool.js
```

Vous devez voir :
```
🎵 BoomTchak V3 — Seed du pool école

  Familles…   ✓ 7 familles
  Patterns…   ✓ 26 patterns
  Grooves…    ✓ 5 grooves

✅ Seed terminé. Le pool école est prêt.
```

> ⚠️ La `service_role` key donne un accès total à la base.  
> Ne la mettez **jamais** dans index.html ni dans un commit Git.

---

## Étape 7 — Assigner les rôles

Par défaut, tout compte Google qui se connecte reçoit le rôle `tx` (enseignant).  
Pour vous attribuer le rôle `mx` (admin) :

1. Lancez l'app, connectez-vous avec votre compte Google
2. Dans Supabase → **Table Editor** → table `profiles`
3. Trouvez votre ligne (votre email), cliquez sur la cellule `role`
4. Changez `tx` → `mx` → **Save**

Pour attribuer le rôle `sx` à un élève :  
Même procédure, changer `tx` → `sx`.

---

## Étape 8 — Déployer

```bash
git add index.html
git commit -m "v3.0.0 — Supabase configuré"
git push
```

GitHub Pages se met à jour automatiquement en quelques secondes.

---

## Vérification finale

1. Ouvrir l'app : https://lesonmusical.github.io/BoomTchak/
2. Cliquer ⚙ (Paramètres) → section **BASE ÉCOLE**
3. Cliquer **Se connecter avec Google** → s'authentifier
4. Vous devez voir votre nom, le badge de rôle, et le message **Synchronisé ✓**
5. Les patterns/grooves du pool école apparaissent avec `source:'school'`

---

## En cas de problème

| Symptôme | Cause probable | Solution |
|---|---|---|
| Erreur `redirect_uri_mismatch` | L'URI de callback Google ne correspond pas | Vérifier étape 4a/4c |
| Erreur 401 après login | Clé anon incorrecte | Re-vérifier étape 2 |
| Seed échoue avec 403 | Service role key incorrecte | Re-vérifier Settings > API |
| Sync renvoie 0 items | Seed pas lancé, ou `approved=false` | Relancer le seed |
| Boucle de redirection | Site URL mal configurée | Vérifier étape 4c |
