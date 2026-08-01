# Ekomat, refonte de la console Admin en landscape

**Destinataire :** Alita (Claude Code)
**Demandeur :** Thrasher
**Date :** 2026-08-01
**Statut :** spec figée, prête à exécution par lots
**Fichier cible :** `index.html`, écran `#s-admin` (lignes ~2436 à 2566 pour le HTML, ~10265 à 11900 pour le JS)

---

## 0. Comment utiliser ce document

Alita, tu ne codes rien avant d'avoir terminé la **Phase 0** en section 3 et remonté tes constats à Thrasher.

Quand une décision est marquée **[DÉCIDÉ]**, tu l'appliques sans la rediscuter. Quand elle est marquée **[À CONFIRMER]**, tu poses la question avant d'écrire la ligne concernée.

Ordre imposé : Phase 0, puis Lot 1, Lot 2, Lot 3, Lot 4. Un lot ne démarre pas tant que le précédent n'a pas passé ses critères d'acceptation (section 11).

**Rappel de la règle permanente du projet :** aucun tiret cadratin, ni dans le code, ni dans les commits, ni dans le chat. Ce document la respecte, ton travail aussi.

---

## 1. État des lieux, mesuré dans le repo

Ce qui suit vient de la lecture du code, pas d'une supposition. Sers-t'en comme point de départ, mais revérifie ce qui est marqué à vérifier.

### 1.1 Ce qui existe aujourd'hui dans `#s-admin`

| Élément | Emplacement | État |
|---|---|---|
| Header rust avec gradient `linear-gradient(135deg,#97422b,#b65a41)` | ligne ~2438 | À conserver, il porte l'identité admin |
| 4 KPI (`kpiUsers`, `kpiPending`, `kpiVerified`, `kpiBlocked`) | ligne ~2453 | À conserver et à étendre |
| 6 onglets horizontaux scrollables (`switchAdminTab`) | ligne ~2475 | À remplacer par une sidebar |
| Onglet Verif, `#verifList` | ligne ~2509 | À conserver |
| Onglet Kòmand, `#adminOrderList` | ligne ~2516 | À transformer, voir section 4 |
| Onglet Itilizatè, `#adminUserList` | ligne ~2523 | À conserver |
| Onglet Pwodwi, `#adminPendingList` | ligne ~2530 | À conserver |
| Onglet Mesaj, `#adminConvoList` | ligne ~2542 | À conserver |
| Onglet Estatistik, 5 conteneurs | ligne ~2554 | À conserver et réorganiser |

### 1.2 Fonctions JS admin existantes

`renderAdmin`, `renderAdminPending`, `renderAdminUsers` (défini deux fois, lignes 10462 et 11887, à vérifier), `renderAdminOrders`, `setAdminOrderTab`, `renderAdminSalesChart`, `renderAdminTopProducts`, `_renderAdminProof`, `_renderAdminVerifyBox`, `adminApproveProduct`, `adminRejectProduct`, `adminReleaseEscrow`, `adminRefund`, `adminResolveDispute`, `adminVerifyPayment`, `openAdminConfirmPayment`, `submitAdminConfirmPayment`, `submitAdminRejectPayment`, `viewAdminConvo`.

**Note :** `renderAdminUsers` apparaît défini deux fois. La seconde définition écrase la première. À trancher en Phase 0, ne supprime rien avant d'avoir identifié laquelle est active.

### 1.2 bis, fonctions admin qui vivent HORS de l'écran `#s-admin` [CRITIQUE]

**Point relevé par Thrasher le 2026-08-01, et c'est un angle mort de la première version de cette spec.**

Trois fonctions admin majeures ne sont pas dans les six onglets. Elles sont accessibles depuis un **bouton flottant, le FAB speed dial** (`setupAdminFab`, ligne ~12235), qui n'apparaît que pour un compte admin :

| Entrée du FAB | Déclencheur | Cible |
|---|---|---|
| `Anons` | `openSheet('announceSheet')` | Publication d'annonces, table `announcements` |
| `Feedback` | `openAdminFeedback()` | Lecture des retours utilisateurs |
| `Banyè` | `openHeroSheet()` | Bannières d'accueil, table `hero_slides` plus carte de marque dans `app_settings` |

**Le FAB est une réponse à une contrainte mobile.** Sur une console desktop à trois colonnes, un bouton flottant en bas à droite n'a plus de justification, et sa position entre en conflit avec le panneau droit. Il doit devenir une **entrée de sidebar** en landscape, tout en restant un FAB en dessous de 768 px.

**Décision [DÉCIDÉ] :** ces trois fonctions deviennent une entrée de sidebar nommée `Kontni` (Contenu), regroupant Bannières, Annonces et Feedback en trois sous-vues. Le FAB reste actif et inchangé en mobile. Aucun code de ces fonctions n'est réécrit, seul le point d'entrée change.

### 1.2 ter, inventaire exhaustif à préserver

**Contrainte absolue : aucune ligne de ce tableau ne peut disparaître.** Alita coche chaque entrée en fin de Lot 1 et prouve son accessibilité dans la nouvelle mise en page. Une case non cochée bloque la clôture du lot.

| # | Fonction | Point d'entrée actuel | Destination landscape |
|---|---|---|---|
| 1 | Vérification vendeurs | onglet Verif, `_renderAdminVerifyBox` | Sidebar `Verifikasyon` |
| 2 | Liste et actions commandes | onglet Kòmand, `renderAdminOrders` | Sidebar `Kòmand`, voir section 4 |
| 3 | Vérifier paiement MonCash | `openAdminConfirmPayment`, `submitAdminConfirmPayment` | Dans `Kòmand`, inchangé |
| 4 | Rejeter paiement | `submitAdminRejectPayment` | Dans `Kòmand`, inchangé |
| 5 | Libérer escrow | `adminReleaseEscrow` | Dans `Kòmand`, inchangé |
| 6 | Rembourser | `adminRefund` | Dans `Kòmand`, inchangé |
| 7 | Résoudre litige | `adminResolveDispute` | Dans `Kòmand`, inchangé |
| 8 | Liste utilisateurs | onglet Itilizatè, `renderAdminUsers` | Sidebar `Itilizatè` |
| 9 | Produits en attente | onglet Pwodwi, `renderAdminPending` | Sidebar `Pwodwi` |
| 10 | Approuver produit | `adminApproveProduct` | Dans `Pwodwi`, inchangé |
| 11 | Rejeter produit | `adminRejectProduct` | Dans `Pwodwi`, inchangé |
| 12 | Conversations | onglet Mesaj, `viewAdminConvo` | Sidebar `Mesaj` |
| 13 | Graphique ventes | onglet Estatistik, `renderAdminSalesChart` | Sidebar `Rezime` et `Estatistik` |
| 14 | Top produits | `renderAdminTopProducts` | Sidebar `Rezime` |
| 15 | Santé escrow | `escrow_overview()`, `#escrowHealth` | Sidebar `Finans` |
| 16 | Entonnoir AARRR | `funnel_overview()`, `#funnelHealth` | Sidebar `Estatistik` |
| 17 | Santé système | `error_overview()`, `#sysHealth` | Sidebar `Estatistik` |
| **18** | **Annonces** | **FAB, `submitAnnouncement`, `genAnnouncement`, `loadAnnouncements`** | **Sidebar `Kontni`, sous-vue Anons** |
| **19** | **Feedback** | **FAB, `openAdminFeedback`** | **Sidebar `Kontni`, sous-vue Feedback** |
| **20** | **Bannières hero** | **FAB, `openHeroSheet`, `submitHeroSlide`, `editHeroSlide`, `deleteHeroSlide`, `moveHeroSlide`, `loadHeroSlides`, `renderHeroPreview`, `pickHeroImage`, `pickHeroCta`, `pickHeroTheme`, `toggleHeroGuides`, `cancelHeroEdit`, `clearHeroImage`, `setHeroImage`, `onHeroCtaLabel`, `onHeroCtaPick`, `paintHeroSwatches`** | **Sidebar `Kontni`, sous-vue Banyè** |
| **21** | **Carte de marque hero** | **`heroBrandSlide`, `saveHeroBrandDraft`, `deployHeroBrand`, `revertHeroBrandDraft`, `askDeployBrand`, `cancelDeployBrand`, `renderBrandState`, `renderHeroBrandPreview`, `loadHeroBrandImage`, `fillBrandForm`, `readBrandForm`, `pickBrandCta`, `pickBrandTheme`** | **Sidebar `Kontni`, sous-vue Banyè** |
| **22** | **Codes promo** | **table `promo_codes`, `validatePromoCode`, création de code parrainage** | **Sidebar `Konfigirasyon`, sous-vue Kòd promo** |
| **23** | **Flash deals** | **table `flash_deals`, création depuis la fiche produit vendeur** | **Vue admin en lecture, sidebar `Pwodwi`. Ne pas déplacer la création vendeur.** |

**Règle de vérification :** avant de clôturer le Lot 1, ouvre la console admin avec un compte admin et déclenche les 23 entrées une par une. Une fonction dont le bouton a disparu est une régression, même si son code est encore dans le fichier.

**Attention particulière sur le hero.** Le système de bannières comporte deux mécanismes distincts qu'il ne faut pas confondre : les diapositives `hero_slides` (plusieurs lignes en base) et la carte de marque, qui vit dans `app_settings` avec un couple brouillon et publié (`hero_brand_draft`, `hero_brand_live`). Ce second mécanisme a son propre flux de publication en deux temps. Ne le fusionne pas avec les diapositives, ne casse pas le cycle brouillon vers publié.

### 1.3 RPC serveur déjà disponibles

- `escrow_overview()` : santé de l'escrow, montants bloqués, libérés, remboursés
- `error_overview()` : santé technique
- `funnel_overview()` : entonnoir AARRR, GMV, revenu net, frais
- `advance_order_status()` : machine à états, SECURITY DEFINER
- `try_seller_otp()`, `hide_order()`, `unhide_order()`, `validate_promo_code()`

Tu as déjà la donnée. La refonte est un travail de présentation et de densité, pas de backend, sauf pour les ajouts de la section 6.

### 1.4 Contrainte majeure, l'app n'a aucun responsive

**Mesure :** zéro occurrence de `md:`, `lg:` ou `xl:` dans `index.html`. 15 occurrences de `max-w-lg`, qui plafonne tout à 512 px.

Ekomat est aujourd'hui 100 % mobile, sans exception. **La console admin en landscape sera le premier écran desktop du produit.** Ce n'est pas une adaptation d'un écran existant, c'est l'introduction d'un second paradigme de mise en page dans un fichier unique. Traite-le comme tel.

---

## 2. Contraintes non négociables

| # | Contrainte | Détail |
|---|---|---|
| C1 | **Rien de supprimé, vérification nominative** | Toute fonctionnalité admin existante reste accessible, **y compris celles qui vivent hors de `#s-admin`** (bannières, annonces, feedback, accessibles aujourd'hui par le FAB). L'inventaire des 23 fonctions à préserver est en section 1.2 ter. Chaque entrée doit être cochée et testée avant clôture du Lot 1. Une instruction générale ne suffit pas, la liste fait foi. |
| C2 | **Architecture mono-fichier** | Tout reste dans `index.html`. Pas de nouveau fichier JS ou CSS. |
| C3 | **Aucune dépendance nouvelle** | Pas de librairie de graphiques, pas de framework de tableau. SVG et CSS natifs. Validation explicite de Thrasher sinon. |
| C4 | **Tailwind précompilé** | Toute classe Tailwind nouvelle impose `npm run build:css` et le commit de `assets/tw.css` dans la même PR. Sans ça, la classe n'a aucun style en production. |
| C5 | **L'admin reste utilisable sur mobile** | Le landscape est la cible, la dégradation mobile doit rester fonctionnelle. Thrasher est en Haïti, il peut avoir à modérer depuis son téléphone. |
| C6 | **Kreyòl** | Toute l'interface admin en Kreyòl, comme l'existant. |
| C7 | **Pas de tiret cadratin** | Règle permanente du projet. |
| C8 | **RLS et RPC inchangés** | Aucun contournement du modèle de sécurité. Toute nouvelle lecture passe par une RPC `SECURITY DEFINER` réservée admin, pas par un `select` direct élargi. |
| C9 | **Migrations** | Toute migration nouvelle dans `supabase/migrations/<timestamp>_nom.sql`, idempotente, avec vérification du run GitHub Actions après merge. |
| C10 | **Discipline de debug** | Reproduire sur le vrai `index.html` servi tel quel. Un correctif qui ne change rien signifie mauvaise couche, pas mauvais réglage. Leçon payée trois fois sur l'onglet admin fantôme (PR #187, #192, #193). |

---

## 3. Phase 0, audit obligatoire

**Tu ne codes pas avant d'avoir répondu par écrit.**

- [ ] **Doublon `renderAdminUsers`** : deux définitions (lignes 10462 et 11887). Laquelle est active ? Que fait l'autre ? Y a-t-il une régression latente ?
- [ ] **Cascade CSS** : où `assets/tw.css` est-il chargé par rapport aux blocs `<style>` inline ? La leçon de la classe `.hidden` neutralisée est documentée dans `LEARNINGS.md`, elle va se reposer sur une sidebar avec états actif et inactif.
- [ ] **`switchAdminTab`** : comment gère-t-elle l'affichage ? Classe `hidden` ou `display` inline ? Ta sidebar devra rester compatible ou remplacer proprement.
- [ ] **Chargement des données** : chaque onglet recharge-t-il au clic, ou tout est-il chargé au montage ? Détermine s'il faut un cache pour éviter des rechargements en cascade dans une vue dense.
- [ ] **Schéma réel contre repo** : `supabase/schema.sql` est périmé (son `CHECK` sur `orders.status` ne contient pas `awaiting_payment`, que le code insère). Interroge la vraie base via le MCP Supabase avant de t'appuyer sur un fichier du repo.
- [ ] **Volume actuel** : combien d'utilisateurs, de produits, de commandes en base ? Détermine s'il faut de la pagination dès le Lot 1 ou si ça peut attendre.
- [ ] **`app_settings`** : quelles clés existent déjà ? La section 6.5 propose un panneau de configuration, il doit s'appuyer sur l'existant.
- [ ] **Contrôle d'accès** : comment l'accès admin est-il vérifié côté client et côté RLS ? `profiles.role` ou `profiles.is_admin` ? Les deux existent, avec un trigger de synchronisation `trg_sync_is_admin`.

**Livrable :** un rapport Markdown court, une réponse par point, avec les chemins de fichiers et les numéros de ligne. Plus la liste des ruptures anticipées.

---

## 4. L'onglet Kòmand, conservé et amélioré [DÉCIDÉ, arbitré par Thrasher le 2026-08-01]

**Décision de Thrasher :** l'onglet Kòmand reste. Rien n'est supprimé. C'est une refonte, pas une amputation. Tous les boutons d'action restent en place.

**Ce que cet onglet contient** (lignes 11222 à 11290) :

- `adminVerifyPayment(orderId)` : valider une preuve de paiement MonCash
- `adminReleaseEscrow(orderId)` : libérer les fonds vers le vendeur
- `adminRefund(orderId)` : rembourser l'acheteur
- `adminResolveDispute(orderId, outcome)` : trancher un litige
- `setAdminOrderTab(tab)` : filtrage interne existant, à conserver

C'est la sortie de caisse de l'escrow. Tout reste accessible et fonctionnel.

### 4.1 Améliorations à apporter, sans rien retirer

**Bandeau d'actions en attente, en haut de l'écran.** Avant la liste complète, une bande horizontale de compteurs cliquables qui filtrent la liste en dessous :

| Compteur | Filtre appliqué |
|---|---|
| `Peman pou verifye (3)` | `awaiting_payment` avec preuve déposée |
| `Escrow pou lage (7)` | `delivered` non libéré |
| `Litij (1)` | `disputed` |
| `Bloke depi 7 jou+ (2)` | escrow ancien, anomalie |
| `Tout kòmand (142)` | aucun filtre, liste complète |

Le dernier compteur garantit que la liste intégrale reste accessible en un clic. Les quatre premiers font remonter ce qui demande une décision, sans jamais cacher le reste.

**Passage en tableau dense au-delà de 1280 px.** La liste actuelle est en cartes empilées, adaptée au mobile. En landscape, une carte par commande gaspille l'écran. Colonnes proposées : identifiant court, date, acheteur, vendeur, produit, montant, statut, actions. Les cartes restent le rendu mobile. Même donnée, deux rendus, voir section 6.6.

**Actions groupées.** Libérer plusieurs escrows en une fois quand plusieurs commandes sont livrées et confirmées. Case à cocher par ligne, barre d'action groupée en bas. **Restriction :** uniquement pour la libération d'escrow sur des commandes au même statut. Jamais de remboursement ni de résolution de litige en masse, ces décisions se prennent une par une.

**Tri et recherche dans la liste.** Tri par date, par montant, par statut. Champ de recherche par identifiant de commande, nom d'acheteur ou de vendeur.

**Colonne d'ancienneté visible.** Depuis combien de temps la commande est dans son état actuel. Une commande livrée depuis 9 jours dont l'escrow n'est pas libéré est un problème, et aujourd'hui rien ne le signale.

**Traçabilité.** Chaque action déclenchée depuis cet onglet écrit dans le journal d'audit de la section 6.4, avec motif obligatoire pour la libération, le remboursement et la résolution de litige.

---

## 5. Architecture de la mise en page landscape

### 5.1 Modèle retenu

Trois colonnes, inspirées de la référence Image 1 (dashboard sombre) pour la structure et de l'Image 2 (Shopify) pour la densité des listes.

```
┌──────────┬────────────────────────────────────┬──────────────┐
│          │  TOPBAR : fil d'ariane, recherche, │              │
│ SIDEBAR  │  thème, rafraîchir, notifications  │   PANNEAU    │
│          ├────────────────────────────────────┤   DROIT      │
│  Nav     │                                    │              │
│  Ekomat  │  ZONE DE TRAVAIL                   │  Aktivite    │
│          │  KPI, graphiques, tableaux         │  Aksyon      │
│  Badges  │                                    │  rapid       │
│  compteur│                                    │              │
│          │                                    │              │
│  Profil  │                                    │              │
│  admin   │                                    │              │
└──────────┴────────────────────────────────────┴──────────────┘
   240px              flexible                      300px
```

### 5.2 Points de rupture [DÉCIDÉ]

| Largeur | Comportement |
|---|---|
| `< 768px` | Layout mobile actuel conservé à l'identique. Onglets horizontaux, `max-w-lg`. Zéro régression. |
| `768px à 1279px` | Sidebar réduite en icônes seules (72 px), panneau droit masqué, son contenu bascule en bas de la zone de travail. |
| `>= 1280px` | Layout complet trois colonnes. |

**Le `max-w-lg` de `#s-admin` doit sauter au-delà de 768 px, et uniquement pour cet écran.** Ne touche à aucun autre `max-w-lg` du fichier.

### 5.3 Sidebar

**[DÉCIDÉ, arbitré par Thrasher le 2026-08-01] Fond rust foncé, pas le noir du template.**

Le noir de la référence appartient à un template SaaS générique. Ekomat est une marque crème et chaude, la sidebar doit le refléter.

| Élément | Couleur | Justification |
|---|---|---|
| Fond sidebar | `#5C2819` | Rust `#97422B` assombri, même famille chromatique |
| Élément actif | `#B65A41` (`tertiary-container`) | Rust clair de la charte, ressort sur le fond foncé |
| Texte inactif | `rgba(252,249,244,.65)` | Crème à 65 %, lisible sans concurrencer l'actif |
| Texte actif | `#FCF9F4` | Crème plein |
| Séparateurs | `rgba(252,249,244,.10)` | Discrets |

**Contrainte de contraste :** le texte inactif à 65 % sur `#5C2819` doit être vérifié au ratio 4.5:1. Si le compte n'y est pas, monte l'opacité, ne baisse pas la taille de police.

**Le teal `#00666F` est réservé aux boutons d'action dans la zone de travail.** Ne l'utilise jamais dans la sidebar, sinon le clic ne ressort plus nulle part. C'est l'effet Von Restorff : une couleur qui sert partout ne signale plus rien.

Structure :

```
┌────────────────────────┐
│ [logo e] Ekomat Admin  │  ← mark rust + libellé
├────────────────────────┤
│ ○ Rezime               │  ← nouveau, voir 6.1
│ ○ Verifikasyon    (3)  │  ← badge compteur
│ ○ Kòmand          (7)  │  ← conservé et amélioré, voir 4
│ ○ Pwodwi          (12) │
│ ○ Itilizatè            │
│ ○ Mesaj                │
│ ○ Kontni               │  ← ex-FAB, voir 1.2 bis
│                        │     Banyè, Anons, Feedback
│ ○ Estatistik           │
│ ○ Finans               │  ← nouveau, voir 6.2
│ ○ Konfigirasyon        │  ← nouveau, voir 6.5
│ ○ Jounal               │  ← nouveau, voir 6.4
├────────────────────────┤
│ [avatar] Thrasher      │
│ Admin                  │
└────────────────────────┘
```

Badges compteur : pastille rouge `#DC2626` avec le nombre, uniquement si supérieur à zéro. Un badge à zéro est masqué, pas affiché en gris.

### 5.4 Topbar

Hauteur 56 px. Contient, de gauche à droite : bouton de repli de la sidebar, fil d'ariane (`Admin / Verifikasyon`), barre de recherche globale (voir 6.3), puis à droite : bascule thème clair et sombre, bouton rafraîchir, cloche de notifications, avatar.

La bascule de thème existe déjà dans l'app (`body.dark`). Réutilise-la, n'en crée pas une seconde.

### 5.5 Panneau droit

Largeur 300 px. Deux blocs empilés :

**Aktivite** : flux temps réel des événements de la plateforme. Nouveau vendeur inscrit, produit publié, commande créée, escrow libéré, litige ouvert. Chaque ligne : icône colorée, texte court, horodatage relatif en Kreyòl (`Kounye a`, `Gen 5 minit`, `Gen 2 èdtan`).

**Aksyon rapid** : quatre boutons vers les tâches les plus fréquentes, alimentés par les compteurs. `Verifye vandè (3)`, `Apwouve pwodwi (12)`, `Lage escrow (2)`, `Rezoud litij (1)`.

---

## 6. Éléments nouveaux à ajouter

Chaque ajout est justifié par un manque constaté dans le code actuel, pas par une envie de remplir l'écran.

### 6.1 Écran Rezime, la vue d'ensemble [PRIORITÉ HAUTE]

**Manque constaté :** aujourd'hui, l'admin s'ouvre sur l'onglet Verifikasyon. Il n'y a aucune vue d'ensemble. Thrasher doit cliquer sur Estatistik pour savoir comment va la plateforme, et sur trois autres onglets pour savoir ce qui l'attend.

**Contenu, de haut en bas :**

**Bandeau KPI, 4 à 6 cartes.** Reprend les 4 existants et ajoute :

| KPI | Source | Format |
|---|---|---|
| GMV total | `funnel_overview()` | Montant HTG, plus variation contre période précédente |
| Revenu net Ekomat | `funnel_overview()`, champ `fees` | Montant HTG |
| Lajan nan escrow | `escrow_overview()`, `in_escrow_htg` | Montant HTG, **le chiffre le plus important de la plateforme** |
| Kòmand aktif | `orders` | Nombre |
| Itilizatè | existant `kpiUsers` | Nombre |
| Vandè verifye | existant `kpiVerified` | Nombre |

Chaque carte affiche la variation contre la période précédente, avec flèche verte ou rouge, comme dans l'Image 1. **Uniquement si la donnée historique existe.** Ne fabrique pas de variation.

**Ligne de graphiques, deux colonnes :**
- Gauche : évolution du GMV sur 30 jours, courbe SVG. Réutilise `renderAdminSalesChart`.
- Droite : répartition des ventes par catégorie, anneau. Les 9 catégories du `CHECK` sur `products.category`. Inspiration Image 1, bloc « Sales Overview ».

**Ligne du bas, deux colonnes :**
- Gauche : top produits, réutilise `renderAdminTopProducts`.
- Droite : top vendeurs par volume de ventes. **Nouveau**, à construire.

### 6.2 Écran Finans [PRIORITÉ HAUTE]

**Manque constaté :** `escrow_overview()` existe et retourne `in_escrow_htg`, `released_htg`, `refunded_htg`, `fees_earned_htg`, mais ces chiffres sont noyés dans un conteneur de l'onglet Estatistik. Sur une marketplace à escrow, la position financière est l'information numéro un.

**Contenu :**
- Position escrow en temps réel : bloqué, libéré ce mois, remboursé, frais encaissés
- Courbe des frais encaissés sur 30 jours
- Liste des commandes dont l'escrow est bloqué depuis plus de 7 jours, triée par ancienneté. **C'est là que se cachent les problèmes.**
- Détection d'incohérences : `escrow_overview()` expose déjà `net_amount <> total_amount - fee_amount`. Affiche-la avec une alerte visible, pas dans un coin.

### 6.3 Recherche globale admin [PRIORITÉ MOYENNE]

**Manque constaté :** pour retrouver un utilisateur ou une commande, il faut ouvrir le bon onglet et faire défiler. Aucune recherche transversale.

Champ dans la topbar, raccourci clavier `Ctrl+K` ou `Cmd+K`. Cherche simultanément sur : utilisateurs (nom, email, téléphone), produits (titre), commandes (identifiant, titre du produit). Résultats groupés par type, navigation clavier.

**Contrainte C8 :** passe par une RPC `SECURITY DEFINER` réservée admin, pas par un élargissement des policies de lecture. `search_products` et `search_sellers` existent déjà, examine si elles sont réutilisables.

### 6.4 Jounal d'aksyon admin [PRIORITÉ HAUTE, sécurité]

**Manque constaté, et c'est le plus grave.** Aucune trace des actions admin. Quand un escrow est libéré, quand un utilisateur est bloqué, quand un produit est rejeté, rien n'est enregistré. Aucun moyen de savoir qui a fait quoi, ni quand, ni pourquoi.

Sur une plateforme qui manipule l'argent d'autrui, c'est une lacune de gouvernance, pas un confort. Le jour où un vendeur conteste une libération de fonds, tu n'as rien à opposer.

**Migration à créer :**

```sql
create table if not exists public.admin_audit_log (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid not null references public.profiles(id),
  action      text not null,        -- 'release_escrow', 'refund', 'block_user', ...
  target_type text not null,        -- 'order', 'user', 'product'
  target_id   uuid,
  reason      text,
  metadata    jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists idx_admin_audit_created on public.admin_audit_log(created_at desc);
create index if not exists idx_admin_audit_admin on public.admin_audit_log(admin_id);
```

RLS : lecture réservée admin, écriture uniquement par RPC `SECURITY DEFINER`. Aucun `INSERT` direct depuis le client.

**L'écriture doit être faite côté serveur, dans les RPC existantes**, pas côté client. Un journal que le client peut ne pas écrire n'est pas un journal.

**Motif obligatoire sur les actions sensibles :** libération d'escrow, remboursement, résolution de litige, blocage d'utilisateur. Une modale demande un motif court avant de valider. Cette friction est voulue.

### 6.5 Écran Konfigirasyon [PRIORITÉ MOYENNE]

**Manque constaté :** `app_settings` existe (`fee_percent` notamment) mais n'a aucune interface. Modifier la commission demande de passer par le tableau de bord Supabase.

Regroupe : taux de commission, zones de livraison, catégories, bannières et `hero_slides` (déjà en base), codes promo (`promo_codes` existe), textes légaux.

**Garde-fou :** toute modification de `fee_percent` demande une confirmation explicite et écrit dans le journal d'audit. Un doigt qui glisse sur ce champ change l'économie de toute la plateforme.

### 6.6 Améliorations transverses des listes

Inspiration Image 2 (Shopify). À appliquer aux listes Itilizatè, Pwodwi et Kòmand :

- **Sélection multiple** avec cases à cocher et barre d'actions groupées. Approuver 12 produits en un geste au lieu de 12.
- **Filtres en onglets** au-dessus de la liste, avec compteurs : `Tout (45)`, `Aktif (30)`, `An atant (12)`, `Bloke (3)`.
- **Tri par colonne**, cliquable.
- **Pagination ou défilement infini** selon le volume mesuré en Phase 0.
- **Vue tableau dense** en landscape, cartes en mobile. Même donnée, deux rendus.
- **Actions en survol** sur la ligne, pas de bouton permanent qui alourdit chaque rangée.

### 6.7 Ce que je n'ajoute pas, et pourquoi

| Écarté | Raison |
|---|---|
| Export CSV et PDF | Utile plus tard, inutile avec 3 vendeurs pilotes. |
| Rôles admin multiples | Un seul admin aujourd'hui. YAGNI. |
| Notifications temps réel par websocket | Le rafraîchissement manuel suffit à cette échelle. Coût de complexité disproportionné. |
| Tableau de bord personnalisable | Complexité élevée, valeur nulle pour un utilisateur unique. |
| Mode sombre spécifique admin | `body.dark` existe déjà, réutilise-le. |

---

## 7. Identité visuelle, application de la charte Ekomat

Source : `BRAND.md`. Aucune couleur hors charte.

| Zone | Couleur | Jeton |
|---|---|---|
| Fond sidebar | `#1C1C19` | `on-surface` |
| Sidebar, élément actif | `#97422B` (rust) | `tertiary` |
| Fond zone de travail | `#FCF9F4` (crème) | `surface` |
| Cartes | `#FFFFFF` | `surface-container-lowest` |
| Bordures | `#BCC9C8` | `outline-variant` |
| CTA et actions primaires | `#00666F` (teal) | `primary` |
| Header admin, gradient | `linear-gradient(135deg,#97422b,#b65a41)` | existant, conservé |
| Succès, validation | `#065F46`, `#059669` | semantic |
| Erreur, blocage | `#991B1B`, `#DC2626` | semantic |
| Alerte, attente | `#92400E`, `#D97706` | semantic |
| Texte principal | `#1C1C19` | `on-surface` |
| Texte secondaire | `#3D4949` | `on-surface-variant` |

**Contre-indication explicite :** l'Image 1 utilise un vert fluo sur fond noir. Ce n'est pas la marque Ekomat. Tu reprends sa **structure et sa densité**, pas sa palette. Le rust et le teal remplacent le vert partout.

**Mode sombre :** utilise les variables `--dm-*` déjà définies dans `BRAND.md` section 5. Ne crée pas de nouvelles variables.

**Graphiques :** teal `#00666F` en série principale, rust `#97422B` en secondaire, puis `#00818C`, `#B65A41`, `#5AD7E6`. Pas de palette arc-en-ciel.

---

## 8. Densité et lisibilité

Une console admin en landscape sert à traiter du volume vite. La densité est une fonctionnalité.

| Élément | Valeur |
|---|---|
| Hauteur de ligne de tableau | 44 px à 48 px |
| Marge interne des cartes | 16 px à 20 px, contre 20 px à 24 px en mobile |
| Taille de police, corps | 13 px à 14 px, contre 15 px à 16 px en mobile |
| Taille de police, tableaux | 13 px |
| Espacement entre blocs | 16 px |
| Largeur maximale de lecture, texte long | 72 caractères |

**Ne réduis pas les cibles tactiles en dessous de 44 px sur mobile.** La densité s'applique au landscape, où le pointeur est une souris.

---

## 9. Découpage en lots

### Lot 1, ossature landscape [bloquant]

Grille trois colonnes, sidebar avec navigation et badges, topbar, panneau droit, points de rupture, dégradation mobile vérifiée. **Aucun changement fonctionnel.** Les six onglets existants sont simplement replacés dans la nouvelle structure.

Critère de sortie : tout ce qui marchait avant marche encore, à l'identique, dans la nouvelle mise en page.

### Lot 2, gouvernance et traçabilité [arbitré par Thrasher le 2026-08-01, passe avant la visualisation]

Table `admin_audit_log` plus RPC d'écriture côté serveur. Branchement de toutes les actions admin existantes sur le journal. Motif obligatoire sur libération d'escrow, remboursement, résolution de litige et blocage d'utilisateur. Écran Jounal en lecture seule.

**Motif de la priorité :** une action non tracée aujourd'hui est perdue définitivement. Chaque jour de retard sur ce lot est un jour d'historique irrécupérable. Un graphique manquant reste un inconfort réparable à tout moment.

**Écran Konfigirasyon inclus dans ce lot**, parce qu'il dépend du journal : une modification de `fee_percent` doit être tracée dès sa première utilisation.

### Lot 3, Rezime, Finans et amélioration Kòmand

Écran Rezime avec KPI étendus et graphiques. Écran Finans. Améliorations de l'onglet Kòmand décrites en section 4.1 : bandeau de compteurs, tableau dense, tri, recherche, colonne d'ancienneté, actions groupées. Alimentation des badges compteur de la sidebar.

### Lot 4, confort

Recherche globale, sélection multiple, filtres en onglets, tri, pagination.

---

## 10. Anti-specs, ce qu'il ne faut pas faire

- Ne pas supprimer les actions escrow, voir section 4
- Ne pas retirer le FAB en mobile, il reste le seul accès aux bannières et annonces en dessous de 768 px
- Ne pas réécrire les fonctions hero, annonces ou feedback, seul leur point d'entrée change
- Ne pas fusionner `hero_slides` et la carte de marque `app_settings`, ce sont deux mécanismes distincts
- Ne pas toucher aux `max-w-lg` des autres écrans
- Ne pas introduire de librairie de graphiques ou de tableau
- Ne pas casser le layout mobile existant
- Ne pas utiliser le vert fluo de la référence
- Ne pas afficher un badge compteur à zéro
- Ne pas fabriquer une variation de KPI sans historique réel
- Ne pas écrire le journal d'audit depuis le client
- Ne pas élargir une policy RLS pour alimenter la recherche globale
- Ne pas dupliquer la bascule de thème existante
- Ne pas oublier `npm run build:css` après ajout de classes Tailwind
- Ne pas utiliser d'emoji comme icône, Material Symbols uniquement, comme l'existant
- Ne pas employer de tiret cadratin

---

## 11. Critères d'acceptation

### Lot 1

- [ ] En dessous de 768 px, l'admin est strictement identique à aujourd'hui
- [ ] À 1280 px et au-delà, les trois colonnes s'affichent correctement
- [ ] Entre 768 px et 1279 px, la sidebar est en icônes seules et rien n'est coupé
- [ ] **Les 23 fonctions de l'inventaire 1.2 ter sont accessibles et testées une par une**
- [ ] Bannières, annonces et feedback sont atteignables depuis la sidebar en landscape
- [ ] Le FAB reste présent et fonctionnel en dessous de 768 px
- [ ] Le FAB est masqué au-delà de 768 px, puisque ses trois entrées sont dans la sidebar
- [ ] Le cycle brouillon vers publié de la carte de marque hero fonctionne toujours
- [ ] Les six onglets existants sont accessibles et fonctionnels
- [ ] `switchAdminTab` fonctionne ou est proprement remplacée, sans onglet fantôme
- [ ] Aucune classe Tailwind sans style, `assets/tw.css` régénéré et commité
- [ ] Vérifié sur le vrai `index.html` servi tel quel, pas sur un harness de test
- [ ] Le mode sombre fonctionne sur toute la console

### Lot 2, gouvernance

- [ ] Toute libération d'escrow écrit une entrée dans le journal, avec motif
- [ ] Remboursement, résolution de litige et blocage d'utilisateur écrivent aussi
- [ ] Le journal est écrit côté serveur, vérifié en coupant le réseau côté client juste après l'action
- [ ] Aucun `INSERT` direct sur `admin_audit_log` n'est possible depuis le client
- [ ] Le journal est en lecture seule depuis l'interface, aucune suppression possible
- [ ] Une modification de `fee_percent` demande confirmation et est tracée
- [ ] Le journal affiche qui, quoi, quand, sur quoi, et pourquoi

### Lot 3, visualisation et Kòmand

- [ ] Le montant bloqué en escrow est visible dès l'ouverture de l'admin
- [ ] L'onglet Kòmand conserve la totalité de ses actions existantes
- [ ] Les compteurs du bandeau Kòmand filtrent la liste sans jamais la tronquer
- [ ] Le compteur `Tout kòmand` ramène la liste intégrale en un clic
- [ ] Les actions groupées ne s'appliquent qu'à la libération d'escrow
- [ ] Les badges compteur de la sidebar correspondent au nombre réel d'éléments
- [ ] Aucun KPI n'affiche de variation inventée

### Lot 4

- [ ] `Ctrl+K` ouvre la recherche, `Échap` la ferme
- [ ] La recherche ne renvoie aucune donnée qu'un non-admin pourrait obtenir
- [ ] La sélection multiple applique l'action à tous les éléments cochés
- [ ] Les compteurs de filtres correspondent au contenu réel

---

## 12. Arbitrages rendus par Thrasher le 2026-08-01

| Question | Décision |
|---|---|
| Palette | **Couleurs Ekomat uniquement.** Jamais celles des templates de référence. Les images servent de structure, pas de palette. |
| Sidebar | **Rust foncé `#5C2819`**, actif `#B65A41`. Voir section 5.3. |
| État actif | Rust clair. Le teal reste réservé aux boutons d'action. |
| Onglet Kòmand | **Conservé intégralement.** Aucun bouton retiré. Refonte et amélioration uniquement. Voir section 4. |
| Priorité | **Journal d'audit avant Rezime et Finans.** Voir Lot 2. |
| Cible d'affichage | Ordinateur. Voir 12.1. |
| Volume en base | Inconnu. Voir 12.2, règle de décision. |

### 12.1 Point de rupture principal

Cible retenue : **1280 px**, avec dégradation propre en dessous.

Motif : un portable courant est en 1366x768 ou 1440x900. À 1366 px, la mise en page à trois colonnes laisse 786 px de zone de travail utile après la sidebar (240 px) et le panneau droit (300 px), plus les marges. C'est suffisant pour un tableau dense, serré pour deux graphiques côte à côte.

**Règle imposée :** entre 1280 px et 1439 px, les graphiques de l'écran Rezime s'empilent sur une colonne au lieu de deux. À partir de 1440 px, deux colonnes. Ne force jamais deux graphiques côte à côte en dessous de 1440 px, ils deviennent illisibles.

**À mesurer en Lot 1 :** demande à Thrasher d'ouvrir la console de son navigateur et de rapporter `window.innerWidth`. Une seule commande, et le point de rupture est calé sur son écran réel plutôt que sur une moyenne.

### 12.2 Volume en base, règle de décision

Thrasher ne connaît pas les volumes. Ne le bloque pas là-dessus, mesure et applique la règle.

Requête à exécuter en Phase 0 via le MCP Supabase, en lecture seule :

```sql
select 'profiles' as t, count(*) from public.profiles
union all select 'products', count(*) from public.products
union all select 'orders',   count(*) from public.orders
union all select 'reviews',  count(*) from public.reviews;
```

Règle à appliquer sans redemander :

| Volume de la plus grosse table | Décision |
|---|---|
| Moins de 200 lignes | Aucune pagination. Chargement complet. Tri et filtre côté client. |
| 200 à 1000 lignes | Pagination côté client, 50 lignes par page. Chargement complet conservé. |
| Plus de 1000 lignes | Pagination côté serveur avec `range()`. Tri et filtre côté serveur. |

**Ne construis jamais de pagination serveur pour 40 lignes.** C'est du travail perdu et une source de bugs. Remonte le résultat de la requête à Thrasher avec la décision appliquée.

---

*Spec construite après lecture du repo `Ekomat-Marketplace`, branche `main`, 611 commits. Références visuelles fournies par Thrasher : dashboard analytique sombre (structure trois colonnes, cartes KPI, flux d'activité) et liste de produits Shopify (densité, sélection multiple, filtres en onglets).*
