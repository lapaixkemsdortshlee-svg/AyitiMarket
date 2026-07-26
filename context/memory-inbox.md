# Memory inbox, leçons en attente de memory_save

> File d'attente pour agentmemory. Quand le moteur est disponible (il ne l'était
> pas dans la session du 2026-07-11 : binaire iii-engine absent + téléchargement
> GitHub Releases bloqué par la politique réseau), seeder chaque entrée avec
> `memory_save` (project: ayitimarket) puis la retirer d'ici.

## 1. CodeQL baseline sur index.html (2026-07-11)

- content: "CodeQL re-signale les alertes baseline d'index.html (fichier ~850 Ko) comme « new alerts » sur TOUT gros diff qui le touche, même un pur remplacement de texte (vu sur PR #99, #151, #152, son résumé dit « code changes were too large »). Méthode de preuve avant de conclure au faux positif : normaliser les tokens variables du diff (sed marque/version) puis vérifier que chaque ligne +/- s'apparie exactement (sort | uniq -c, tout à 2) → zéro logique JS changée. Documenter en commentaire de PR et merger."
- concepts: codeql-baseline-faux-positif, index-html-gros-diff, preuve-diff-symetrique, ci-pr-rouge
- files: index.html

## 2. Assets de marque = fichiers de Thrasher (2026-07-11)

- content: "Les assets de marque Ekomat (logo wordmark, mark « e » à anse, icônes, favicon, og-image, palette BRAND.md) sont les fichiers créés par Thrasher (designer). Ne JAMAIS les recréer ou les approximer (veto explicite « pa defòme li » quand Alita a tenté une recréation SVG depuis des captures) : demander les originaux (upload GitHub). Les dérivés mécaniques de SES fichiers (resize, crop, pose sur fond cream, conversion ico) sont OK. Fichiers canoniques dans brand/."
- concepts: assets-marque-thrasher, logo-ekomat-originaux, pas-de-recreation, brand-folder
- files: brand/logo-ekomat.png, brand/mark-cream.png, BRAND.md

## 3. Rituel skills + checklist obligatoire (2026-07-11)

- content: "Thrasher a recadré Alita DEUX FOIS le 2026-07-11 sur la même erreur : exécuter tête baissée sans activer les skills installés ni afficher de checklist. Règle durable (gravée dans CLAUDE.md) : avant toute tâche non triviale, activer les skills pertinents (typiquement 3 à 10 cumulés, ex. ayitimarket + quick-recap + skills métier), afficher une checklist visible des étapes, et nommer chaque skill activé en une ligne. Il a investi ~150 skills pour la puissance d'exécution : les négliger le déçoit plus qu'une erreur technique."
- concepts: rituel-skills-checklist, recadrage-methode-thrasher, activation-skills-multiple, discipline-execution
- files: CLAUDE.md

## 5. db-migrate échoue après reset du mot de passe DB (2026-07-11, récurrent)

- content: "Le workflow db-migrate.yml échoue à `supabase db push` avec `password authentication failed for user postgres (SQLSTATE 28P01)` quand le secret GitHub SUPABASE_DB_PASSWORD est périmé, typiquement après que Thrasher a reset le mot de passe DB dans Supabase (le `supabase link` passe quand même car il utilise SUPABASE_ACCESS_TOKEN, seul le push utilise le mot de passe DB). Déjà vu le 2026-07-05. Symptôme trompeur : list_migrations peut montrer une migration antérieure appliquée (poussée AVANT le reset) alors que la nouvelle échoue. Fix (Thrasher seul) : Supabase Settings→Database reset le mot de passe en le tapant, puis GitHub repo Settings→Secrets→Actions mettre SUPABASE_DB_PASSWORD = cette valeur exacte (PAS anon/service_role), puis re-run le workflow. Contournement agent quand une migration approuvée+validée+idempotente est bloquée par ça : l'appliquer via mcp Supabase apply_migration (elle reste cohérente, le push la sautera ensuite). Le GitHub MCP ne peut pas re-run un workflow (403)."
- concepts: db-migrate-password-auth-failed, supabase-db-password-secret-perime, reset-mot-de-passe-db, apply-migration-contournement, pipeline-migrations-casse
- files: .github/workflows/db-migrate.yml

## 6. supabase db push CI : SASL/pooler + mismatch mot de passe (2026-07-11)

- content: "Le workflow db-migrate (supabase db push en CI) échoue avec 'failed SASL auth / password authentication failed (28P01)' quand le secret GitHub SUPABASE_DB_PASSWORD ne matche pas exactement le mot de passe DB courant. Diagnostic vérifié via docs Supabase officielles (search_docs): (1) vérifier Network Bans dans Dashboard > Database > Settings (re-runs répétés peuvent bannir l'IP, ici 0 ban); (2) le pooler Supavisor peut cacher l'ancien mot de passe qq minutes après un reset; (3) db push depuis GitHub Actions passe FORCÉMENT par le pooler session (IPv4-only), --skip-pooler exige IPv6 donc inutilisable en CI. Piège classique: changer le mot de passe d'un seul côté (Supabase OU le secret) au lieu des deux avec la MÊME valeur. Conseil: mot de passe alphanumérique pur (évite tout souci d'échappement d'URL par le CLI). Décision Thrasher 2026-07-11: laisser le pipeline de côté, déployer les migrations via mcp Supabase apply_migration (fiable, idempotent), le pipeline n'est qu'un confort, il ne bloque rien. Un debug SÛR dans le workflow: afficher ${#SUPABASE_DB_PASSWORD} (longueur seule, jamais la valeur) pour détecter vide/espace/retour-ligne."
- concepts: db-push-sasl-auth, pooler-supavisor-cache, secret-mismatch-deux-cotes, mcp-apply-migration-fallback, mot-de-passe-alphanumerique
- files: .github/workflows/db-migrate.yml

## 7. Fix écran de choix de rôle = DROP DEFAULT sur profiles.role (2026-07-11)

- content: "L'écran 'Ki wòl ou sou Ekomat?' (choix achtè/vandè) ne s'affichait pas pour les nouveaux comptes car profiles.role avait un DEFAULT 'buyer' ET le trigger handle_new_user crée le profil sans rôle -> tout nouveau compte = 'buyer', donc handleAuthSession ne voyait jamais 'pas de rôle' (needsRoleSelection reste faux) et sautait l'écran. Fix (validé Thrasher, appliqué via MCP): alter table public.profiles alter column role drop default. Le code gère déjà role NULL -> needsRoleSelection -> écran affiché -> supabaseSaveRole() persiste le choix. Comptes existants inchangés. Réversible."
- concepts: ecran-choix-role, profiles-role-default-buyer, handle-new-user-trigger, needsRoleSelection, drop-default
- files: index.html, supabase/migrations/20260711230000_profiles_role_drop_default.sql

## 8. gstack s'invoque via le routeur `gstack`, jamais `/browse` en direct (2026-07-12)

- content: "gstack EST installé dans l'environnement remote (~/.claude/skills/gstack, ~83 sous-dossiers dont browse/ qa/ ship/, restauré à chaque container frais par .claude/hooks/session-start.sh). Dans ce harness les sous-commandes gstack NE sont PAS enregistrées comme skills autonomes : seul le skill routeur `gstack` est exposé (skill_prefix=false par défaut). Donc appeler Skill('browse') échoue avec 'Unknown skill: browse', ce n'est PAS une absence d'install, c'est une mauvaise invocation. Toujours passer par le routeur `gstack` (ou config gstack skill_prefix pour exposer les préfixes). Alita a fait cette erreur le 2026-07-12 et conclu à tort 'gstack pas installé'. Corollaire: avant de déclarer un skill/outil absent, vérifier ~/.claude/skills/ sur le disque."
- concepts: gstack-routeur, sous-skills-gstack-non-autonomes, unknown-skill-browse, mauvaise-invocation-pas-absence, verifier-disque-avant-conclure
- files: ~/.claude/skills/gstack/SKILL.md, .claude/hooks/session-start.sh

## 9. Boutique vendeur en mémoire + empty-state col-span en multicol (2026-07-12)

- content: "Deux bugs de rendu produits (index.html, PR #162). (1) renderSellerProfile() (boutique publique d'un vendeur, ~ligne 13978) filtrait le tableau EN MÉMOIRE PRODUCTS au lieu d'interroger Supabase -> selon le chemin de nav (session fraîche, arrivée depuis commande/message/deep-link) un vendeur qui a des produits actifs affichait '0 pwodwi'. Fix: openSellerProfile() await loadSellerProductsFromSupabase(sellerId) (select status=active + join profil) avant le rendu. (2) emptyState() renvoyait class='col-span-2' (utilitaire GRID Tailwind) mais le feed #feedGrid est en CSS `columns:2` (MULTICOL) où col-span-2 n'a AUCUN effet -> bloc icône+titre+sous-titre+bouton écrasé dans une colonne ('positionnement incohérent'). Fix layout-robuste: grid-column:1/-1 (grid) + column-span:all (multicol) + width:100% (flow/flex) sur le wrapper. Leçon générale: distinguer conteneur grid vs multicol avant d'utiliser col-span-*. Contexte: la vraie base n'a qu'1 produit actif (3 en tout, 2 archivés) -> le 'vide' était surtout réel, pas un bug."
- concepts: renderSellerProfile-in-memory, boutique-vendeur-supabase, empty-state-col-span-multicol, columns-vs-grid, feed-1-produit-actif
- files: index.html
