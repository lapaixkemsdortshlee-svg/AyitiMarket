# Ekomat, plan d'exécution pour Alita

**Auteur :** Thrasher
**Date :** 2026-08-01
**Nature :** ordre de mission séquentiel, à exécuter objectif par objectif
**Emplacement dans le repo :** `docs/PLAN-EXECUTION.md`

---

## Étape préalable, à faire par Thrasher une seule fois

`docs/ekomat-page-produit-spec.md` est déjà commité. On garde la même convention, fichiers à plat dans `docs/`, pas de sous-dossier `specs/`.

```bash
mkdir -p docs/assets
mv ~/Downloads/ekomat-admin-refonte-spec.md   docs/2026-08-01-admin-landscape.md
mv ~/Downloads/ekomat-admin-mockup.html       docs/assets/admin-mockup.html
mv ~/Downloads/ekomat-plan-execution-alita.md docs/PLAN-EXECUTION.md
git mv docs/ekomat-page-produit-spec.md       docs/2026-07-29-page-produit.md

git add docs
git commit -m "docs: plan d'execution, spec console admin landscape, maquette"
```

**Puis rends le plan visible sans effort.** Ajoute cette ligne dans `CLAUDE.md`, à la fin du bloc `ALITA` :

```markdown
- `docs/PLAN-EXECUTION.md` : ordre de mission séquentiel en cours. Consulte-le
  au début de toute session de développement et respecte l'ordre des objectifs.
```

Sans cette ligne, Alita ne lira le plan que si tu le lui dis à chaque session. Avec elle, il est chargé au même titre que `CONTEXT.md`.

Ensuite, dans Claude Code, colle le bloc de la section suivante.

---

## Le prompt à coller dans Claude Code

> Alita, lis `docs/PLAN-EXECUTION.md` et exécute-le à partir de l'Objectif 0.
>
> Règles de session :
> 1. Un seul objectif à la fois. Tu ne démarres jamais le suivant sans mon accord explicite.
> 2. À la fin de chaque objectif, tu t'arrêtes et tu me remets un rapport court : ce qui est fait, ce que tu as vérifié et comment, ce qui reste, et les questions ouvertes.
> 3. Si un constat contredit une spec, tu me le dis avant de coder. La spec a été écrite depuis une lecture du repo, pas depuis la base réelle. La base réelle a autorité.
> 4. Applique le rituel d'ouverture de `CLAUDE.md` : active les skills pertinents, affiche ta checklist, nomme ce que tu actives et pourquoi.
> 5. Mode sparring partner actif. Si un objectif te paraît mal cadré, dis-le avant de l'exécuter, pas après.

---

## Cartographie des fichiers

| Fichier | Rôle | Quand le lire |
|---|---|---|
| `docs/PLAN-EXECUTION.md` | Ce document. Ordre des objectifs, critères de passage. | Au début, puis à chaque changement d'objectif |
| `docs/2026-08-01-admin-landscape.md` | Spec console admin. Inventaire des 23 fonctions à préserver, mise en page, journal d'audit. | Objectifs 1, 3, 4, 5 |
| `docs/2026-07-29-page-produit.md` | Spec page produit. Variantes, galerie, attributs, avis. **Contient des erreurs corrigées en Objectif 2, lis l'avertissement.** | Objectif 2 |
| `docs/assets/admin-mockup.html` | Maquette visuelle de la console admin. Couleurs, densité, hiérarchie. Aperçu, pas du code de production. | Objectifs 3 et suivants |
| `CLAUDE.md` | Règles projet, pipeline migrations, Tailwind précompilé, rituel d'ouverture. | Chaque session |
| `LEARNINGS.md` | Règles permanentes et leçons payées. | Avant toute action |
| `BRAND.md` | Palette Ekomat, source de vérité couleurs. | Tout travail visuel |
| `CLAUDE-sparring-partner.md` | Posture par défaut. | Chaque session |
| `docs/AUDIT-CHEMIN-CRITIQUE.md` | **Audit du chemin critique vers le pilote, écrit le 2026-07-17.** Source de vérité sur l'état réel des rails escrow, paiement, litiges, notifications. Il cite `admin_actions`, la table d'audit qui existe déjà. | Avant les Objectifs 0 et 1, obligatoire |
| `docs/PROTOCOLE-PILOTE-FERME.md` | Protocole du pilote fermé, étape par étape. Définit ce qui doit fonctionner et dans quel ordre. | Avant tout arbitrage de priorité |
| `docs/SECURITY-CHECKLIST.md` | Checklist sécurité existante. | Objectif 0 |
| `docs/QA-PLAN.md` | Plan de QA existant. | Avant toute clôture d'objectif |

**Avant l'Objectif 0, lis `docs/AUDIT-CHEMIN-CRITIQUE.md` en entier.** Ce document a été écrit depuis la vraie base, en lecture seule, et il est plus fiable que les specs. Plusieurs affirmations des specs ont déjà été corrigées grâce à lui.

**Autorité en cas de conflit :** base réelle interrogée via le MCP Supabase, puis `docs/AUDIT-CHEMIN-CRITIQUE.md`, puis `LEARNINGS.md`, puis `CLAUDE.md`, puis les specs. Une spec qui contredit la base réelle est une spec fausse, tu me le signales.

**Règle de méthode, leçon payée le 2026-08-01.** Avant d'affirmer qu'une table, une fonction ou une policy n'existe pas, cherche dans **les trois sources** :
1. `supabase/migrations/*.sql`, les migrations récentes au format CLI
2. `supabase/migration-2026-*.sql`, **les fichiers historiques, déjà déployés à la main**
3. la base réelle via le MCP Supabase

Conclure depuis les seules migrations récentes produit des faux négatifs. C'est exactement l'erreur qui a fait réclamer une table `admin_audit_log` alors que `admin_actions` existait depuis `migration-2026-05.sql`. « Absent des migrations récentes » ne signifie pas « absent de la base », et `LEARNINGS.md` le dit déjà : une preuve répond à la question qu'elle pose, jamais à celle d'à côté.

---

## OBJECTIF 0, audit et sécurisation des montants [BLOQUANT PILOTE]

**Pourquoi en premier :** tant que ce point n'est pas tranché, chaque commande réelle est une prise de risque. Aucun travail d'interface ne passe avant.

### 0.1 Vérification, en lecture seule

Interroge la vraie base via le MCP Supabase, projet `htxfwxldzaocuwezzbom` :

```sql
-- Triggers sur orders
select tgname, pg_get_triggerdef(oid) from pg_trigger
where tgrelid = 'public.orders'::regclass and not tgisinternal;

-- Contraintes CHECK sur orders
select conname, pg_get_constraintdef(oid) from pg_constraint
where conrelid = 'public.orders'::regclass and contype = 'c';

-- Policies sur orders
select polname, pg_get_expr(polqual, polrelid) as using_expr,
       pg_get_expr(polwithcheck, polrelid) as check_expr
from pg_policy where polrelid = 'public.orders'::regclass;

-- Volumes, sert aussi à l'Objectif 3
select 'profiles' as t, count(*) from public.profiles
union all select 'products', count(*) from public.products
union all select 'orders',   count(*) from public.orders
union all select 'reviews',  count(*) from public.reviews;
```

### 0.2 Le constat à confirmer ou infirmer

Dans `index.html`, autour de la ligne 8254, le montant de la commande est calculé côté client puis inséré directement :

```js
const unitPrice   = p.p;
const totalAmount = unitPrice * qty;
const feeAmount   = Math.round(totalAmount * feePct);
const netAmount   = totalAmount - feeAmount;
await db.from('orders').insert({ unit_price, total_amount, fee_amount, net_amount, ... })
```

La seule policy d'insertion trouvée dans les migrations vérifie `auth.uid() = buyer_id`. Elle ne contrôle aucun montant.

**Hypothèse à valider :** un acheteur authentifié peut insérer une commande à un montant arbitraire. L'escrow bloque alors le montant qu'il a choisi, pas le prix du produit.

**Ne conclus pas depuis les fichiers du repo.** `supabase/schema.sql` est périmé, son `CHECK` sur `orders.status` ne contient pas `awaiting_payment` alors que le code l'insère. La base a divergé. Un trigger a pu être créé au tableau de bord sans migration.

### 0.3 Si la faille est confirmée

Écris une RPC `SECURITY DEFINER` `create_order(...)` qui :
- relit `products.price` et `app_settings.fee_percent` depuis la base
- calcule `unit_price`, `total_amount`, `fee_amount`, `net_amount` côté serveur
- vérifie le stock et le statut du produit
- refuse toute valeur de montant transmise par le client
- retourne la commande créée

Puis retire la policy `orders_insert_buyer` et bascule le client sur la RPC.

C'est le même patron que ton durcissement `UPDATE` du 2026-07-17 (`20260717140000_harden_orders_update_rls.sql`), appliqué à l'entrée au lieu de la sortie. Relis ce fichier, il donne la forme.

### 0.4 Critères de passage

- [ ] Les quatre requêtes ont été exécutées et leurs résultats me sont rapportés
- [ ] Le verdict sur la faille est tranché, confirmé ou infirmé, avec la preuve
- [ ] Si confirmée : la RPC existe, la policy directe est retirée, le client est bascule
- [ ] Un test manuel prouve qu'une insertion directe avec un montant falsifié est rejetée
- [ ] Le run GitHub Actions de la migration est vérifié après merge
- [ ] Le volume des quatre tables m'est rapporté, avec la règle de pagination applicable (section 12.2 de la spec admin)

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 1, compléter et exposer le journal d'audit

**Référence :** `docs/2026-08-01-admin-landscape.md`, section 6.4 et Lot 2.

### CORRECTION IMPORTANTE, la table existe déjà

La spec admin, section 6.4, affirme qu'aucune action admin n'est tracée et demande de créer `admin_audit_log`. **C'est faux, et cette instruction est annulée.**

`public.admin_actions` existe depuis `supabase/migration-2026-05.sql` (ligne 95), avec :
- colonnes `admin_id`, `order_id`, `action`, `from_status`, `to_status`, `note`
- index sur `order_id` et sur `(admin_id, created_at desc)`
- RLS admin-only, policy `admin_actions_admin_only`, revue dans `20260711131500_perf_rls_initplan_fk_indexes.sql`
- **écriture côté serveur** dans `advance_order_status` (ligne 222), reprise dans `migration-2026-escrow-guards.sql` et `20260718230000_bugfix_test_2_3_moun.sql`

`docs/AUDIT-CHEMIN-CRITIQUE.md` et `docs/PROTOCOLE-PILOTE-FERME.md` la citent tous les deux.

**Ne crée aucune table `admin_audit_log`. Ne duplique pas ce qui existe.**

### Ce qui reste réellement à faire

1. **Audit de couverture.** Interroge la base et liste les valeurs distinctes de `action` réellement écrites. Puis compare avec l'inventaire des actions admin : `adminReleaseEscrow`, `adminRefund`, `adminResolveDispute`, `adminVerifyPayment`, `submitAdminRejectPayment`, `adminApproveProduct`, `adminRejectProduct`, blocage d'utilisateur, vérification vendeur, modification de `app_settings`.

```sql
select action, count(*), min(created_at), max(created_at)
from public.admin_actions group by action order by 2 desc;

select column_name, data_type, is_nullable
from information_schema.columns
where table_schema='public' and table_name='admin_actions';
```

2. **Combler les trous.** La table est centrée sur les commandes (`order_id`, `from_status`, `to_status`). Les actions hors commande n'y entrent probablement pas. Deux options, tu proposes, je tranche :
   - étendre `admin_actions` avec `target_type` et `target_id` nullables, `order_id` restant pour la compatibilité
   - ou créer une seconde table pour les actions non transactionnelles

   Je penche pour l'extension. Deux journaux à consulter pour reconstituer une histoire, c'est un journal et demi.

3. **Vérifier le motif.** Le champ `note` existe. Est-il réellement rempli lors d'une libération ou d'un remboursement, ou reste-t-il vide ? Si vide, ajoute la modale de saisie obligatoire sur les actions sensibles : libération, remboursement, résolution de litige, blocage.

4. **Exposer la donnée.** Aucune interface n'affiche `admin_actions` aujourd'hui. Tu as l'historique, tu ne peux pas le lire. Écran de consultation en lecture seule. À ce stade, un septième onglet dans la mise en page mobile actuelle suffit, il sera déplacé dans la sidebar à l'Objectif 3.

**Ne fais pas :** de mise en page landscape, de recherche, de filtres avancés. Ça vient plus tard.

**Critères de passage :**

- [ ] La couverture actuelle de `admin_actions` m'est rapportée, action par action
- [ ] Les actions non couvertes sont identifiées et la solution retenue est validée avec moi
- [ ] Toute action sensible écrit une entrée avec un motif non vide
- [ ] Test de preuve : coupe le réseau côté client juste après avoir déclenché une action, l'entrée est quand même en base
- [ ] Le journal est consultable depuis l'interface admin, en lecture seule
- [ ] Aucune table en doublon n'a été créée

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 2, variantes produit [conditionnel]

**Référence :** `docs/2026-07-29-page-produit.md`, Lot 1.

### AVERTISSEMENT, cette spec contient des erreurs

Elle a été écrite avant la lecture du repo. Cinq points sont faux, corrigés ici. **Ces corrections priment sur le texte de la spec.**

| Point de la spec | Réalité du code | Correction |
|---|---|---|
| Créer un système de tailles | `products.sizes TEXT[]` existe déjà, sélecteur affiché ligne 5729, libellé « Tay » | Ne recrée rien. **Mais `selSz(this)` ne fait que changer une classe CSS. La taille choisie n'est jamais transmise au panier ni à la commande.** C'est le vrai bug, en production aujourd'hui. |
| Modifier `order_items` | Cette table n'existe pas. Chaque ligne de panier devient sa propre ligne `orders` | Adapte la section 4.8 à la table `orders` |
| `category_variant_axis` avec clé étrangère vers `categories` | `products.category` est un `CHECK` texte à 9 valeurs, il n'y a pas de table `categories` | Soit tu crées la table, soit tu indexes les axes sur la valeur texte. Propose, ne décide pas seule. |
| Construire un système d'avis | La table `reviews` existe, avec `rating`, `comment`, `video_url`, `UNIQUE(reviewer_id, product_id)` | C'est un raccordement, pas une construction |
| Le document contient des tirets cadratins | Interdit par `LEARNINGS.md` | N'en reproduis aucun dans le code ou les commits |

### Condition de déclenchement

**Question à me poser avant de commencer :** les vendeurs du pilote vendent-ils des articles à variantes, vêtements et chaussures, ou de l'électronique sans déclinaison ?

- **Articles à variantes** : cet objectif est bloquant, exécute-le maintenant.
- **Électronique sans déclinaison** : reporte-le après l'Objectif 5. Corrige uniquement le bug de la taille non transmise, qui reste une source de litige même avec un seul axe.

**Priorité minimale dans tous les cas :** la taille sélectionnée doit arriver jusqu'à `orders` et jusqu'à l'écran de livraison. Un acheteur qui croit choisir une taille et reçoit autre chose déclenche un litige que tu ne peux pas arbitrer.

**Critères de passage :** ceux du Lot 1 de la spec page produit, plus une transaction end-to-end complète avec un produit à variante.

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 3, ossature landscape de la console admin

**Référence :** `docs/2026-08-01-admin-landscape.md`, Lot 1. Maquette : `docs/assets/admin-mockup.html`.

**Ce qui est demandé :** la structure, sans aucun changement fonctionnel. Sidebar rust `#5C2819` avec actif `#B65A41`, topbar, panneau droit, points de rupture, dégradation mobile.

**Le piège principal.** L'app n'a aujourd'hui aucun responsive : zéro `md:`, `lg:` ou `xl:` dans `index.html`, et 15 `max-w-lg`. Cette console est le premier écran desktop d'Ekomat. Tu introduis un second paradigme de mise en page dans un fichier unique.

- Le `max-w-lg` de `#s-admin` saute au-delà de 768 px, **et uniquement celui-là**. Ne touche à aucun autre.
- En dessous de 768 px, l'admin reste strictement identique à aujourd'hui.
- Relis la leçon de `LEARNINGS.md` sur `.hidden` neutralisée par la cascade. Une sidebar avec états actif et inactif va reposer exactement le même problème. Reproduis sur le vrai `index.html` servi tel quel, jamais sur un harness qui réécrit le HTML.
- Après tout ajout de classe Tailwind : `npm run build:css` et commit de `assets/tw.css` dans la même PR.

**L'inventaire des 23 fonctions, section 1.2 ter de la spec, fait foi.** Tu ouvres la console avec un compte admin et tu déclenches les 23 entrées une par une. Une fonction dont le bouton a disparu est une régression, même si son code est encore là. Attention particulière aux entrées 18 à 21, bannières, annonces et feedback, qui vivent aujourd'hui dans le FAB speed dial et non dans l'écran admin.

**Deux mécanismes à ne pas confondre :** `hero_slides` (plusieurs diapositives en base) et la carte de marque (`app_settings`, couple `hero_brand_draft` et `hero_brand_live`, avec son cycle brouillon puis publication). Ne les fusionne pas.

**Critères de passage :** ceux du Lot 1 de la spec admin, dont les 23 cases cochées.

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 4, Konfigirasyon et Kontni

**Référence :** spec admin, sections 6.5 et 1.2 bis.

- Écran `Konfigirasyon` : `fee_percent`, zones, catégories, codes promo, textes légaux. Toute modification de `fee_percent` demande confirmation et écrit dans le journal de l'Objectif 1.
- Écran `Kontni` : regroupe bannières, annonces et feedback dans la sidebar. Le FAB reste actif et inchangé sous 768 px. **Aucun code de ces fonctions n'est réécrit, seul le point d'entrée change.**

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 5, Rezime, Finans et amélioration Kòmand

**Référence :** spec admin, Lot 3.

- Écran `Rezime` avec KPI étendus. Le montant bloqué en escrow doit être visible dès l'ouverture, en carte rust pleine.
- Écran `Finans` : position escrow, courbe des frais, commandes bloquées depuis plus de 7 jours, détection d'incohérence `net_amount <> total_amount - fee_amount`.
- Améliorations de `Kòmand` selon la section 4.1 : bandeau de compteurs, tableau dense, tri, recherche, colonne d'ancienneté, actions groupées limitées à la libération d'escrow.

**Rien n'est retiré de `Kòmand`.** Tous les boutons d'action existants restent. Le compteur `Tout kòmand` ramène la liste intégrale en un clic.

**Interdiction :** aucune variation de KPI affichée sans donnée historique réelle. Ne fabrique pas un pourcentage.

**Stop. Rapport. Attends mon accord.**

---

## OBJECTIF 6, confort

**Référence :** spec admin, Lot 4.

Recherche globale `Ctrl+K`, sélection multiple, filtres en onglets, tri par colonne, pagination selon la règle établie à l'Objectif 0.

La recherche globale passe par une RPC `SECURITY DEFINER` réservée admin. **N'élargis aucune policy de lecture existante.** `search_products` et `search_sellers` existent, regarde si elles sont réutilisables avant d'en écrire une nouvelle.

---

## OBJECTIF 7, reste de la page produit

Lots 2, 3 et 4 de la spec page produit : galerie 8 images avec compression client, bloc vendeur, bloc livraison, bloc confiance escrow, attributs, garantie encadrée, avis, produits similaires.

À ce stade, relis la spec en entier. Plusieurs mois auront passé depuis sa rédaction, et le contexte aura bougé.

---

## Règles valables sur tous les objectifs

1. **Jamais de tiret cadratin**, nulle part.
2. **Architecture mono-fichier.** Tout dans `index.html`. Le workspace Alita reste dans `context/` et `.claude/`.
3. **Aucune dépendance nouvelle** sans mon accord explicite.
4. **Migrations** dans `supabase/migrations/<timestamp>_nom.sql`, idempotentes, run Actions vérifié après merge. Si tu appliques via MCP en secours, réconcilie immédiatement `supabase_migrations.schema_migrations`, sinon `db push` casse.
5. **Tailwind précompilé.** Toute classe nouvelle impose `npm run build:css` et le commit de `assets/tw.css` dans la même PR.
6. **Discipline de debug.** Un correctif qui ne change rien signifie mauvaise couche, pas mauvais réglage. Trois réglages ratés du même paramètre signifient que c'est le paramètre qui est faux.
7. **Avant de dire que c'est fini :** applique `verification-before-completion`. Une preuve répond à la question qu'elle pose, pas à celle d'à côté.
8. **Après chaque correction de ma part**, enregistre la leçon selon `ecriture-pro-et-lecons`.
9. **Kreyòl** pour toute chaîne visible côté utilisateur.
10. **Un objectif à la fois.** Tu ne prends pas d'avance, même si l'objectif suivant te paraît trivial.

---

## Tableau de suivi

| # | Objectif | Bloquant pilote | État |
|---|---|---|---|
| 0 | Audit et sécurisation des montants | Oui | À faire |
| 1 | Compléter et exposer `admin_actions` | Partiel | À faire |
| 2 | Variantes produit | Conditionnel | À faire |
| 3 | Ossature landscape admin | Non | À faire |
| 4 | Konfigirasyon et Kontni | Non | À faire |
| 5 | Rezime, Finans, Kòmand | Non | À faire |
| 6 | Confort admin | Non | À faire |
| 7 | Reste page produit | Non | À faire |

Mets à jour la colonne État après chaque objectif validé, et commite ce fichier avec le changement.
