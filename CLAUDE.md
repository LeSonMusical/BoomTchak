# BoomTchak — Instructions Claude Code

## Projet
App web pédagogique rythme, single-file `index.html` (~6000 lignes), vanilla JS, Supabase.
Lire `BoomTchak_v3_bible.md` (technique) avant toute modification.

## Règles de collaboration
- Lamberio = product owner. Questions archi importantes → soumettre AVANT de coder.
- Langue : français. Variables/fonctions : camelCase anglais.
- Version `MAJEUR.MINEUR.PATCH` bumpée à chaque commit (dans `<span class="app-version">`).

## Règle de déploiement (OBLIGATOIRE)
Après chaque push de branche feature :
1. Créer une PR draft si elle n'existe pas
2. **Merger immédiatement la PR vers `main`** (l'utilisateur teste depuis GitHub Pages)
3. Pousser `main` : `git push origin main`

Ne jamais laisser `main` en retard sur la branche de travail.

## Branche de travail
Merger vers : `main` après chaque session

## Stack
- Frontend : HTML/CSS/JS vanilla (zéro dépendance)
- Backend : Supabase REST API (fetch natif, pas de SDK)
- Auth : Google OAuth implicit flow
- Déploiement : GitHub Pages (fichier statique)

## Fichiers de référence
- `index.html` — application complète
- `BoomTchak_v3_bible.md` — architecture, rôles, DB, workflows TX/MX
- `supabase/schema.sql` — schéma Supabase
- `supabase/seed_school_pool.sql` — données initiales école

## Prochaines tâches prioritaires (session suivante)


## Conventions
- Commentaires en français, code en anglais
- Pas de framework, pas de bibliothèques
- Mobile-first (testé sur smartphone)
