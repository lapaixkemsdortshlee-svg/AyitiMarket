# CONTEXT.md

> Mon contexte personnel et professionnel pour Alita, mon assistant IA dédié à Ekomat (ex-AyitiMarket).
> Ce fichier est chargé au début de chaque session. Il est mis à jour au fil du temps par Alita.

---

## Qui je suis

- **Prénom :** Thrasher
- **Ville / Pays :** Delmas, Haïti
- **Situation actuelle :** Fondateur d'Ekomat (ex-AyitiMarket) à plein temps, étudiant en anglais dans une école de langue, et graphic designer.
- **Profil dominant :** Entrepreneur (avec une casquette étudiant et une casquette créatif / designer)

---

## Ce que je fais

### Activité principale

Je construis **Ekomat** (ex-AyitiMarket, rebrandée le 2026-07-11), une marketplace multi-vendeurs pensée pour la communauté haïtienne, en Haïti et dans la diaspora. Elle permet d'acheter et de vendre facilement en ligne, avec une interface entièrement en Kreyòl.

### Détails (profil entrepreneur)

- **Activité :** Marketplace en ligne pour Haïti et la diaspora.
- **Modèle économique :** Frais de plateforme (commission) sur les transactions, sécurisées par un système d'escrow (l'argent est bloqué jusqu'à la livraison).
- **Clients types :** Acheteurs et vendeurs haïtiens, plus la diaspora qui achète ou soutient des vendeurs locaux.

---

## Mes objectifs

### Objectifs déjà ATTEINTS ✅

- **Objectif A - QA & Durcissement** : flux escrow testés E2E, RLS/RPC durcis, audit sécurité complet traité (XSS, search_path, least-privilege) - advisors Supabase : zéro alerte non intentionnelle.
- **Objectif B - Croissance / Acquisition** : parrainage bout-en-bout (crédit parrain), SEO + AI-SEO (sitemap, llms.txt, landing pages Kreyòl), mesure du funnel AARRR. Reste seulement les ads (reportées, coût).
- **Objectif C - Observabilité escrow** : monitoring temps réel, réconciliation, alerting, error tracking - clôturé.
- **Déploiement mobile prêt** : app packageable PWA → Android (Google Play) et iOS (App Store) via Capacitor. Guide complet : `docs/DEPLOYMENT-GUIDE.md` (v2.0.0 MVP Final ; bundle ID mis à jour au rebrand : `com.ayitidigital.ekomat`).
- **Audit chemin-critique vers le pilote** (2026-07-17) : checklist rouge/jaune/vert des 6 rails, auditée sur le vrai code + la vraie base (`docs/AUDIT-CHEMIN-CRITIQUE.md`). Constat clé : le rail argent MANUEL fonctionne E2E — le pilote n'attend pas l'API MonCash. Le seul bloqueur (RLS UPDATE sur orders contournant la machine à états) corrigé et vérifié en prod (PR #198).

### Objectifs court terme (3 à 6 mois)

- Ne jamais arrêter de progresser sur Ekomat, pour en faire une entreprise fiable, au service de tous les Haïtiens.
- **Publier l'app sur les stores** : builds Android (.aab) + iOS (.ipa), comptes Google Play ($25) et Apple Developer ($99/an), soumission (voir `docs/DEPLOYMENT-GUIDE.md`).
- **Rebrand ✅ nom choisi : EKOMAT (2026-07-11).** Thrasher a choisi le nom et créé l'identité visuelle (logo : « e »-boule rust avec anse teal + wordmark « eko » rust / « mat » teal, palette BRAND.md). L'app, les contenus, les docs et les logos (déposés par Thrasher, intégrés partout : login/splash, icônes, favicon, og-image) sont rebrandés ; projet Vercel et repo GitHub renommés. **Domaine choisi le 2026-07-25 : `ekomathaiti.com`** (11,25 $/an) — `ekomat.com` est pris par une société d'un autre pays et d'un autre secteur, donc aucun conflit de marque (droit territorial et sectoriel), et `ekomathaiti.com` ancre en plus la marque au pays. Registrar conseillé : Cloudflare (prix coûtant à vie) ou Vercel (branchement en 2 clics). **Reste** : acheter le domaine, le brancher sur Vercel et mettre à jour les URLs (`ayiti-market.vercel.app` reste l'URL active en attendant) ; redéployer les edge functions ; renommer Firebase/Google OAuth.
- **Exécuter le pilote fermé (COURT TERME, PRIORITAIRE — l'audit est fait, place au terrain).** Protocole complet : `docs/PROTOCOLE-PILOTE-FERME.md` (2026-07-17). **Décision révisée (2026-07-17, session 3) : le SMS OTP est REPORTÉ** (abonnement Twilio pas maintenant) — le pilote tourne sur la vérification **CIN/Paspò seule** (validation admin manuelle, déjà fonctionnelle) et le vendeur saisit son numéro MonCash payout à la main. Il ne reste donc qu'**UNE action : recruter 2-3 vrais vendeurs contrôlés** + 1-2 acheteurs contrôlés par vendeur. Critère de succès : ≥3 transactions `released` sur ≥2 vendeurs → enchaîner sur le closed testing Google Play. Cadrage Thrasher inchangé : « pas de démo, préparer l'infra pour de vrais résultats ». Le goulot n'est plus technique du tout.
- **Acquisition de vendeurs (objectif prévu, pas maintenant)** : faire venir des vendeurs pour remplir le catalogue. C'est le vrai goulot (vs l'outillage de recherche). À activer **après** l'audit chemin-critique et le pilote fermé, quand Thrasher le décide. (État base 2026-07-12 : 3 produits en tout, 1 seul actif — catalogue quasi vide, normal, pas un bug.)
- Brancher les vrais paiements MonCash automatisés (bloqué tant que les credentials Digicel ne sont pas obtenus). **Nuance (audit 2026-07-17) : c'est de l'automatisation, pas un prérequis — le flux manuel (vérif ref + payout à la main) suffit au pilote.**
- Lancer l'acquisition payante (ads Meta/Google) quand le budget le permet + activer Leaked Password Protection (plan pro).

### Projets notés, PAS à exécuter maintenant

- **SMS OTP vendeur via Twilio (décision 2026-07-17, session 3)** : nécessite un abonnement Twilio (Supabase → Auth → Providers → Phone) — objectif noté, pas maintenant. Le code est prêt (`smsRequestOtp`/`smsVerifyOtp`, dégrade proprement sans provider). À activer quand Thrasher souscrit ; en attendant, vérification vendeur = CIN/Paspò seule.
- **Feed « mode découverte » pour catalogue clairsemé (décision 2026-07-16)** : tant que le catalogue est petit, basculer le feed en mode découverte (boutiques mises en avant en grand, produits en liste, CTA Vin Vandè proéminent) avec bascule automatique vers la grille masonry dense quand le catalogue grossit. Contexte : les comptes actuels sont des comptes de test, Thrasher ne s'attarde pas sur le feed pour l'instant. À réévaluer quand de vrais vendeurs remplissent le catalogue.
- **Points de fidélité (idée notée 2026-07-24, à évaluer APRÈS le pilote)** : programme de rétention (points gagnés à l'achat, échangeables contre une réduction). Avis Alita (sparring) : bonne idée sur le principe (le funnel montre « moun ki achte ankò » comme étape clé), mais **prématurée** — le goulot actuel est l'acquisition (0 vrai vendeur, catalogue vide), pas la rétention ; un programme sur catalogue vide est mort-né. **Piège marketplace à trancher AVANT de coder : qui finance les points ?** (dépense marketing plafonnée côté plateforme vs coût vendeur opt-in) — sinon ça grignote la marge de 3%. Exploiter d'abord le **parrainage existant** (même levier, déjà en place). Attention : points → réduction touche prix/commission/escrow = surface de bugs. Départ simple recommandé quand on l'active : points gagnés à l'escrow `released`, petite réduction, budget plafonné.

### Objectifs long terme (1 à 3 ans)

- Faire d'Ekomat la marketplace de référence en Haïti et pour la diaspora.
- **Automatiser toutes les tâches admin par l'IA dans l'app, via n8n** (orchestration IA des flux admin : vérifications, escrow, modération, paiements, alertes...). À l'avenir, pas maintenant.

---

## Mes projets en cours

- **Ekomat** (ex-AyitiMarket ; unique projet actif, tout mon focus est dessus). Repo GitHub renommé `Ekomat-Marketplace` et projet Vercel `ekomat-marketplace` le 2026-07-11 (l'ancien nom redirige).

---

## Mes outils et préférences

### Outils que j'utilise au quotidien

- GitHub (code et suivi via PR / issues)
- Supabase (base de données, RLS, edge functions)
- Vercel (déploiement et previews)
- Firebase Cloud Messaging (notifications push)
- MonCash / Digicel (paiements, intégration en attente de credentials)
- Claude Code (développement assisté)
- Outils de design graphique (casquette designer)

### Style de communication préféré

Direct, efficace et précis, mais bien détaillé quand il le faut. Français, tutoiement, sans tirets longs.

### Domaine où j'ai besoin du plus d'aide

Un mix : stratégie produit, développement, croissance / marketing, et productivité.

---

## Notes importantes

> Cette section se remplit au fil du temps avec les éléments de contexte qui émergent naturellement dans mes sessions.

- **Vision IA-first :** tout doit reposer sur l'IA. Alita est au centre du projet, pas un outil secondaire.
- **Veille par défaut (`/morning`) :** IA, e-commerce / marketplace, et tech en Haïti et pour la diaspora.
- **Règles techniques Ekomat à toujours respecter :** architecture single-file (`index.html`), chaînes de caractères en Kreyòl, soft-delete, machine à états escrow via RPC. Le workspace Alita ne doit jamais vivre dans `index.html`.
- **Canal sortant d'Alita (décision 2026-07-05) : push + email seulement.** Les routines notifient par push (app Claude) et email. WhatsApp écarté pour l'instant (API Business payante) ; à reconsidérer seulement si, après ~1 mois de routines, les pushes se révèlent insuffisants.
- **Routines actives (depuis 2026-07-05, notifs push+email confirmées le 2026-07-09) :** Morning brief (7h Haïti, quotidien, push+email), Santé hebdo (lundi 8h, push+email), Sentinelle (17h, quotidien, silencieuse si RAS, push+email). Lecture seule ; les actions d'argent restent à Thrasher. Détail : `context/ROADMAP-AUTONOMIE.md`.
- **Appels vocaux in-app (décision 2026-07-17) : reportés après le build natif.** Le chat texte est le canal principal. Le bouton d'appel du chat affiche un message beta Kreyòl et n'expose plus le numéro du vendeur (plus de `tel:`). Raisons : en PWA, impossible de faire sonner une app fermée (CallKit/ConnectionService natifs requis) + serveur TURN payant indispensable en mobile-à-mobile. À réévaluer après le build Capacitor, si l'usage le réclame.
- **Comptes de la plateforme (bascule 2026-07-25) :** l'admin est désormais **`ekomatmarketplacehaiti@gmail.com`** (aussi l'email de support client affiché dans les conditions et la politique de confidentialité). L'ancien `ayitimarket01@gmail.com` est devenu **« Ekomat Boutique »**, la boutique première-partie de Thrasher : vendeur vérifié + officiel (aucune vérification CIN à faire), marqué d'un **badge or** distinct du teal des vendeurs vérifiés. Il n'a **jamais été supprimé** car il porte la piste d'audit argent. Règle retenue : l'or signifie « boutique officielle » (un état), pas « vendeur premium » (un rang) — sinon les vrais vendeurs réclameraient un badge inatteignable.
- **Base remise à ZÉRO pour le pilote (2026-07-25) :** les 7 comptes existants étant tous des tests, toutes les données transactionnelles ont été supprimées (commandes, avis, notifications, vues, messages, actions admin, promos, favoris, flash deals) et les compteurs remis à 0. **Les 5 produits et les 7 profils sont conservés.** Escrow et statistiques affichent 0 : c'est voulu, pas un bug. Les comptes internes sont marqués `internal_account = true` et exclus du funnel comme des graphiques admin, donc **le premier vrai vendeur pilote produira des chiffres vrais dès le jour 1**.
- **Mémoire des leçons (depuis 2026-07-25) :** skill `ecriture-pro-et-lecons` dans `~/.claude/skills`, et `LEARNINGS.md` versionné à la racine du dépôt. Le fichier enregistre les corrections de Thrasher pour qu'elles survivent aux sessions ; le skill vit hors du dépôt, d'où l'intérêt d'y garder le fichier. Les règles permanentes sont lues avant chaque action, dont l'interdiction du tiret cadratin sur tous les supports. Le bloc « Avant toute action » de CLAUDE.md rend cette relecture systématique et non occasionnelle.
- **Arsenal de skills étendu et auto-extensible (depuis 2026-07-02) :** en plus des skills de base, on a une suite ASO (39 skills) pour la sortie stores, `markitdown` (fichiers vers Markdown), `claude-council` (stress-test de décisions, sans clé API), et un `deep-research` maison (recherche multi-sources via WebSearch/WebFetch, gratuit). `find-skills` permet d'en chercher/installer de nouveaux à la demande. Principe retenu : privilégier les skills gratuits qui tournent dans Claude Code, écarter les apps autonomes qui exigent des clés API payantes (Thrasher reste économe).
