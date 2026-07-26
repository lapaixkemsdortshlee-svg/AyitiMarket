# Roadmap Autonomie d'Alita

> Les 4 chantiers pour faire d'Alita un agent qui agit sans attendre une session,
> validés par Thrasher le 2026-07-05. Ordre de priorité : 1 → 2 → 3 → 4.
> Chaque case cochée = étape faite ET vérifiée. Alita met ce fichier à jour au fil des sessions.
>
> **Garde-fou permanent :** les routines et automatisations sont en lecture/rapport par défaut.
> Toute action d'argent (release escrow, remboursement, paiement vendeur) reste décidée par Thrasher.

---

## Chantier 1 : Autonomie planifiée (routines) 🥇

**But :** Alita travaille même quand aucune session n'est ouverte, et ne dérange Thrasher que s'il y a quelque chose à dire.
**Coût :** zéro. L'infra (triggers planifiés + notifications push) existe déjà.
**Note horaire :** Haïti = UTC-5 toute l'année. 7h00 Port-au-Prince = 12h00 UTC.

### Étapes

- [x] **1.1 (Thrasher)** Vérifier que les notifications push de l'app Claude sont activées sur ton téléphone (sinon les routines parleront dans le vide).
- [x] **1.2 (Alita)** Créer la routine **« Morning brief »** : quotidienne, `0 12 * * *` UTC (7h00 Haïti), session fraîche, prompt autonome qui exécute l'esprit de `/morning` (veille IA/e-commerce/Haïti filtrée par CONTEXT.md) + état rapide du projet (PRs ouvertes, dernier déploiement). Notification **push + email** (passé de push-seul à push+email le 2026-07-09 : les briefs tiraient bien à 7h mais la push du matin se perdait côté téléphone, l'email est le filet fiable).
- [x] **1.3 (Alita)** Créer la routine **« Santé hebdo »** : lundi `0 13 * * 1` UTC (8h00 Haïti), session fraîche : advisors Supabase (sécurité + perf), `error_overview()`, `escrow_attention_orders()`, KPIs `funnel_overview()`. Rapport synthétique + notification.
- [x] **1.4 (Alita)** Créer la routine **« Sentinelle »** : quotidienne `0 22 * * *` UTC (17h00 Haïti) : vérifier `error_logs` récents et commandes escrow en attente anormale. **Silencieuse si RAS** (pas de notification), alerte seulement si problème.
- [x] **1.5 (Alita)** Tester chaque routine avec un déclenchement manuel (`fire_trigger`) et vérifier que la notification arrive chez Thrasher. ✅ Notification de test reçue et confirmée par Thrasher le 2026-07-05.
- [x] **1.6 (Thrasher)** Après 1 semaine : valider les horaires et le niveau de bruit (trop / pas assez), ajuster. ✅ Validé le 2026-07-23 : niveau de bruit « parfait, garde tel quel » et horaires « bons » (brief 7h, santé lundi 8h, sentinelle 17h). Aucun ajustement. Le rythme réel = 1 notif/jour (brief) + 1/semaine (lundi), sentinelle muette si RAS.

### Vérification du chantier
Une semaine complète où : le brief du matin arrive seul, le rapport du lundi arrive seul, et la sentinelle n'a rien envoyé les jours sans problème.

---

## Chantier 2 : Boucle de déploiement Supabase 🥈

**But :** une migration mergée sur `main` = une migration déployée en prod. Fin du « à déployer côté Thrasher au SQL Editor ».
**Approche :** GitHub Action + Supabase CLI (`supabase db push`). Le MCP Supabase reste en lecture seule (sain).
**Point délicat :** nos migrations historiques (`supabase/migration-2026-*.sql`) ne suivent pas la convention CLI (`supabase/migrations/<timestamp>_nom.sql`). On ne les migre PAS : elles sont déjà déployées. On adopte la convention CLI **pour les nouvelles migrations seulement**, avec une baseline propre.

### Étapes

- [x] **2.1 (Thrasher)** Créer un **access token Supabase** : dashboard → compte (avatar) → Access Tokens → « Generate new token » (nom : `github-actions-migrate`). Le copier.
- [x] **2.2 (Thrasher)** Retrouver le **mot de passe de la base** (Settings → Database → Database password ; le reset si perdu).
- [x] **2.3 (Thrasher)** Ajouter 2 **GitHub Secrets** (repo → Settings → Secrets and variables → Actions) : `SUPABASE_ACCESS_TOKEN` et `SUPABASE_DB_PASSWORD`. (Le project ref `htxfwxldzaocuwezzbom` n'est pas secret, il ira dans le workflow.)
- [x] **2.4 (Alita)** Créer le dossier `supabase/migrations/` + workflow `.github/workflows/db-migrate.yml` : sur push vers `main` touchant `supabase/migrations/**` → `supabase link --project-ref htxfwxldzaocuwezzbom` puis `supabase db push`. Concurrency group pour éviter deux déploiements simultanés.
- [x] **2.5 (Alita)** Établir la **baseline** : marquer l'état actuel de la prod comme point de départ de l'historique de migrations CLI (pour que `db push` n'essaie jamais de rejouer les anciennes migrations). Vérifier avec `supabase migration list`.
- [x] **2.6 (Alita)** Test de bout en bout : une migration no-op (`select 1;` commentée) mergée sur `main` → l'Action passe → vérifier via MCP (`list_migrations`) qu'elle est enregistrée en prod. ✅ Vérifié le 2026-07-05 : `20260705050000 (pipeline_test)` enregistrée en prod (après correction du secret `SUPABASE_DB_PASSWORD` : 1er run rouge : mauvais mot de passe DB, corrigé par reset + update du secret, re-run vert).
- [x] **2.7 (Alita)** Documenter la nouvelle règle dans `CLAUDE.md` : toute nouvelle migration va dans `supabase/migrations/<timestamp>_nom.sql` (plus jamais de fichier ad hoc), idempotente, et les changements destructifs (DROP, DELETE) exigent une revue explicite de Thrasher avant merge.

### Vérification du chantier
Une vraie migration (la prochaine feature) déployée en prod par le merge seul, zéro action manuelle.

### Tradeoff assumé
Un token Supabase vit dans les secrets GitHub. Risque contenu : secrets GitHub chiffrés, token révocable à tout moment, et le MCP de session reste read-only. Alternative refusée : donner le write au MCP (trop de pouvoir en session interactive).

---

## Chantier 3 : Mémoire qui capitalise 🥉

**But :** Alita arrête de redécouvrir les mêmes leçons. Les apprentissages durables survivent aux sessions, au-delà de HISTORY.md.
**Outil :** agentmemory (déjà installé : `remember` / `recall` / `handoff`).

### Étapes

- [x] **3.1 (Alita)** Semer les leçons déjà payées (une entrée `remember` chacune, avec tags) :
  - Le navigateur du sandbox ne joint PAS Supabase (proxy TLS) ; QA API = curl/MCP, QA UI = CI.
  - Les installeurs interactifs (npx sans TTY) hangent dans le sandbox ; toujours chercher un mode non-interactif.
  - `profiles.categories` n'existe pas en prod ; le write dans le flux verification échoue en silence ; catégories vendeur = dérivées des produits.
  - `profiles.location` = texte libre → tout filtre zone doit être en ILIKE, jamais en égalité.
  - Boutique = `display_name` du profil vendeur (pas de table boutique).
  - Les commits de merge GitHub apparaissent « unverified » au stop-hook : normal, pas nos commits.
  - Le service worker cache-first a déjà masqué des fixes (bump `aym-vXX` + network-first HTML depuis v29).
- [x] **3.2 (Alita)** Câbler la discipline dans `CLAUDE.md` (section Alita) : à chaque leçon technique durable → `remember` immédiat ; au début d'un travail sur un sujet → `recall` le sujet ; à la fin d'une session importante → HISTORY.md (journal) + `remember` (leçons).
- [x] **3.3 (Alita)** Hygiène HISTORY.md : lors des `/update`, compresser les entrées de plus de 2 mois en un résumé (le journal reste lisible, le détail vit dans git).
- [x] **3.4 (Alita)** Vérifier dans une session suivante : `recall "supabase sandbox"` retourne la leçon du proxy ; `recall "zone location"` retourne la leçon ILIKE. ✅ Vérifié le 2026-07-09 (début de session `/prime`) : les deux recall retournent la bonne leçon.

### Vérification du chantier
Une session future où Alita cite une leçon retrouvée via `recall` au lieu de la redécouvrir en la re-testant.

---

## Chantier 4 : Canal de communication sortant 🏅

**But :** les alertes et briefs atteignent Thrasher là où il vit (téléphone), pas seulement dans une session.
**Position sparring :** commencer GRATUIT. Push (chantier 1) + email couvrent 90 % du besoin. WhatsApp est le canal naturel d'Haïti mais l'API Business coûte de l'argent (Twilio/360dialog via Zapier) : on ne paie que si le besoin est prouvé.

### Étapes

- [x] **4.1 (déjà couvert par 1.x)** Notifications push des routines = canal par défaut.
- [x] **4.2 (Alita)** Canal email : les routines importantes (santé hebdo, alertes sentinelle) envoient aussi un email récapitulatif à lapaixkemsdortshlee@gmail.com (via les notifications email des routines, ou un draft Gmail).
- [ ] **4.3 (Thrasher, plus tard, si besoin prouvé)** WhatsApp : décider seulement après 1 mois de routines. Si les pushes suffisent → ne rien payer. Sinon : Zapier → Twilio WhatsApp (compter ~qq $/mois), Alita configure le Zap.
- [x] **4.4 (Alita)** Documenter le choix final dans CONTEXT.md.

### Vérification du chantier
Une alerte sentinelle réelle reçue par Thrasher hors session, sur au moins un canal, avec le contexte suffisant pour agir.

---

## Suivi

| Chantier | État | Dernière mise à jour |
|---|---|---|
| 1. Routines | ✅ TERMINÉ, briefs tirent seuls, notifs push+email confirmées ; bilan de bruit validé par Thrasher (rythme parfait, horaires bons) | 2026-07-23 |
| 2. Déploiement Supabase | ✅ TERMINÉ, pipeline validé de bout en bout (migration test en prod via le workflow) | 2026-07-05 |
| 3. Mémoire | ✅ TERMINÉ : 7 leçons semées, discipline câblée, recall vérifié (2026-07-09) | 2026-07-09 |
| 4. Canal sortant | ✅ Décidé : push + email, WhatsApp écarté (revoir dans 1 mois si besoin) | 2026-07-05 |
