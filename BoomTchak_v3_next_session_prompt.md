# Prompt — Prochaine session BoomTchak v3

> À copier-coller en début de nouvelle session Claude Code.

---

Lis `CLAUDE.md` et `BoomTchak_v3_bible.md` dans le répertoire courant.
Ce sont les deux documents de référence du projet. On continue le développement de BoomTchak v3.

**Contexte rapide :**
BoomTchak est une app web pédagogique pour l'enseignement du rythme.
Single-file `index.html` (~6000 lignes), vanilla JS, Supabase (Postgres + Auth).
Rôles : MX (admin école), TX (enseignant), SX (élève).
Version courante : v3.4.1 sur `main`.

**Règles impératives :**
- Développer sur la branche `claude/boomtchak-v3-planning-PxL9F`
- Après chaque push : merger immédiatement vers `main` et pousser (cf. CLAUDE.md)
- Bumper la version à chaque commit

---

## Tâches à traiter dans cette session (par priorité)

### 🔴 Priorité 1 — Bug critique : "Connexion en cours…" bloquant

**Symptôme :** Au démarrage, l'app reste parfois figée sur "Connexion en cours…" indéfiniment.

**Cause identifiée :** Dans `initAuth()`, si `sbFetchProfile()` échoue silencieusement
(token expiré → 401 → catch → `authProfile` reste `null`), la condition
`authSession` est toujours truthy → `renderAuthUI()` affiche "Connexion en cours…" à l'infini.

**Fix à appliquer dans `initAuth()` :**
```javascript
async function initAuth() {
  sbLoadSavedSession();
  const wasCallback = await sbHandleOAuthCallback();
  renderAuthUI();
  if (authSession) {
    await sbFetchProfile();
    if (!authProfile) {
      // Token invalide ou profil absent → déconnecter proprement
      authSession = null;
      localStorage.removeItem('sb_session');
    }
    renderAuthUI();
    if (authSession && authProfile) {
      if (wasCallback || !packCours.patterns.some(p => p.source === 'school')) {
        await sbSyncSchoolPool();
      } else {
        updateSyncStatus('Base école chargée depuis le cache local');
      }
    }
  }
}
```

### 🔴 Priorité 2 — MX doit pouvoir tout sauver en DB école

Actuellement MX ne peut publier que via le workflow Soumettre/Approuver.
Il faut ajouter des boutons "↑ DB École" pour MX sur :
- **Patterns** : renommer + publier séquence directement (sans passer par soumission)
- **Grooves** : idem
- **Encyclopédie** : bouton "Sauvegarder en DB" dans la section encyclo (MX seulement)
- **Familles** : déjà en place via `sbSaveFamille` — vérifier que ça fonctionne bien

### 🟡 Priorité 3 — Ordre des items persisté en DB

Ajouter une colonne `ordre int` sur les tables `familles`, `patterns`, `grooves`.
Sauvegarder l'ordre lors des réorganisations MX.
À la sync, restaurer l'ordre depuis DB.

### 🟡 Priorité 4 — Familles TX transmises à la soumission

Quand TX soumet un pattern/groove, pousser d'abord ses familles TX (`scope:'teacher'`)
en DB afin que MX puisse voir les noms de familles corrects dans la section Approbations.

---

## Rappel des gaps identifiés (cf. bible §9)

- **G0** : Bug initAuth() ← traiter en priorité absolue
- **G1** : Fork item école (TX veut modifier un item école → copie source:'teacher')
- **G2** : Familles TX → DB au moment soumission
- **G3** : Suppression locale → annulation Supabase auto si localStatus:'submitted'
- **G4** : MX → tout sauver en DB école
- **G5** : Encyclo MX → DB
- **G6** : Édition tempo/signature post-création groove
- **G7** : Raison de refus (message MX → TX)
- **G8** : Ordre items persisté

---

## Note sur le document BoomTchak_Explain.md

Ce document (fusion de v2_brief + v3_bible en un document complet pédagogie/UX/technique/roadmap)
n'a pas pu être généré en raison de timeouts répétés lors de l'écriture de gros fichiers.
À créer lors d'une prochaine session en écrivant par sections successives via scripts bash.
