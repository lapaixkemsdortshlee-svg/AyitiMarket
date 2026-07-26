# Protocole du pilote fermé

> Objectif unique et fini : **une transaction réelle de bout en bout réussie**
> (commande → escrow → paiement MonCash → livraison → OTP → libération des
> fonds → avis), avec 2-3 vrais vendeurs contrôlés et de vrais acheteurs.
> Pas de démo, pas de données fausses, pas d'acquisition de masse.
>
> Basé sur `docs/AUDIT-CHEMIN-CRITIQUE.md` (2026-07-17). Le rail argent est
> MANUEL et fonctionnel : l'API Digicel n'est pas requise pour le pilote.
> S'aligne avec le closed testing Google Play (~20 testeurs, 14 jours) : le
> pilote peut se faire dedans.

---

## 0. Portes d'entrée (à valider AVANT de recruter)

| # | Porte | État | Qui |
|---|---|---|---|
| G1 | Durcissement RLS `orders` en prod (UPDATE participants retiré) | ✅ fait (PR #198, appliqué + vérifié 2026-07-17) | : |
| G2 | ~~Provider SMS configuré~~ **REPORTÉ** (décision 2026-07-17 : abonnement Twilio pas maintenant), le pilote tourne sur la vérification CIN/Paspò seule | ⏸ reporté | : |
| G3 | ~~Test SMS réel~~ **REPORTÉ** (dépend de G2) | ⏸ reporté | : |
| G4 | Compte admin opérationnel : accès MonCash marchand au numéro `50936803970`, solde suffisant pour rembourser si litige | ⬜ | Thrasher |
| G5 | Numéro MonCash payout renseigné pour CHAQUE vendeur pilote (`profiles.moncash_number`), saisi À LA MAIN à l'onboarding (pas d'auto-remplissage OTP tant que G2 est reporté), sinon `adminReleaseEscrow` bloque (« Vandè a pa antre nimewo MonCash li ») | ⬜ | vendeurs (guidés à l'onboarding) |

**Plus aucune porte technique.** G4/G5 sont opérationnelles ; la seule action restante avant de dérouler = recruter.

---

## 1. Casting, qui recruter

**2-3 vendeurs**, critères stricts (le pilote teste les rails, pas le marché) :

- Personne de confiance, joignable par WhatsApp/téléphone à tout moment du test.
- A un smartphone Android correct + compte MonCash actif à son nom.
- A de VRAIS produits à vendre (3-5 minimum), physiquement disponibles à Delmas
  ou zone convenue, l'app est pickup-based (« Zòn Kolekte »).
- Accepte le jeu : suivre le flux complet, remonter chaque friction, tolérer un
  bug. Dire clairement : « se yon tès reyèl, ak vrè lajan, men sou yon ti echèl ».

**1-2 acheteurs contrôlés** par vendeur (amis/famille, PAS le compte admin de
Thrasher, l'admin vérifie et libère, il ne peut pas être juge et partie sur la
transaction témoin). Chaque acheteur a MonCash et peut se déplacer au point de
collecte.

**Montants** : première transaction entre 500 et 2 000 HTG. Assez réel pour
compter, assez petit pour rembourser sans douleur si ça casse.

---

## 2. Onboarding vendeur, script (séance guidée, ~30-45 min, en personne ou WhatsApp)

Principe (skill onboarding) : un seul objectif par séance, le vendeur doit
atteindre son « aha » : *premye pwodwi pibliye*, en une séance, et son vrai
« aha » : *lajan sou MonCash li*, à la première vente.

**Étape A : Kont (5 min).** Inscription (email ou Google), choix wòl « Vandè ».
Vérifier en base : `profiles.role='seller'`.

**Étape B : Verifikasyon (10 min + délai admin).** CIN oswa Paspò (l'OTP SMS
est reporté : G2). Annoncer : « verifikasyon an ka pran 24-48 èdtan, men pou
pilòt la m ap apwouve w menm jou a ». Admin approuve dans la journée.
Vérifier : `verified_seller=true`.

**Étape C : MonCash payout (5 min).** Saisir le numéro payout À LA MAIN dans
Modifye Pwofil (pas d'auto-remplissage tant que l'OTP SMS est reporté). Dire
pourquoi : « se sou nimewo sa a kòb ou ap rive lè yon lavant fini ». Vérifier
ensemble le numéro chiffre par chiffre (c'est là que l'argent part) :
`moncash_number` non vide et exact (G5).

**Étape D : Premye pwodwi (10 min).** Le vendeur publie lui-même (pas nous à sa
place : « do, don't show ») : foto reyèl, non, pri, kategori, zòn. Objectif :
3-5 produits publiés avant de partir. Vérifier : `products.status='active'`.

**Étape E : Simulation du jour J (5 min).** Expliquer le déroulé d'une vente,
dans ses mots : « yon kliyan kòmande → ou resevwa notifikasyon → ou prepare
pwodwi a → kliyan an vini ak yon kòd 6 chif → ou antre kòd la → admin lage kòb
la sou MonCash ou ». Insister : **ne jamais donner le produit sans valider
l'OTP dans l'app**, c'est ça, la protection escrow.

À chaque étape, noter les frictions verbatim (c'est de la donnée produit).

---

## 3. Transaction témoin №1, déroulé supervisé

Thrasher observe en direct (admin panel ouvert) ; Alita en suivi lecture seule
(requêtes §4). Un seul flux, pas deux en parallèle pour la №1.

| # | Acteur | Action | Statut attendu | On surveille |
|---|---|---|---|---|
| 1 | Acheteur | Commande le produit (panier → checkout) | `awaiting_payment` | notification vendeur + admin reçues ? OTP généré ? |
| 2 | Acheteur | Envoie le montant MonCash au `50936803970`, colle la référence | `payment_submitted` | tunnel MonCash 3 étapes compris sans aide ? `paid_at` posé ? |
| 3 | Thrasher (admin) | Vérifie la réception réelle sur MonCash, confirme dans l'app | `payment_verified` | délai de vérification (cible < 1h) ; notifs deux parties |
| 4 | Vendeur | Prépare et marque « pare » | `ready_for_pickup` | le vendeur trouve le bouton seul ? |
| 5 | Acheteur | Se déplace, donne son kòd 6 chif au vendeur | : | rencontre réelle au point de collecte |
| 6 | Vendeur | Saisit l'OTP dans l'app | `otp_confirmed` | saisie du premier coup ? (5 échecs = litige auto) |
| 7 | Thrasher (admin) | Envoie le payout MonCash au vendeur À LA MAIN (net = total − 3%), puis « Lage lajan » | `released` | montant net exact ; notif « Lajan libere » reçue ; `admin_actions` loggé |
| 8 | Acheteur | Note le vendeur (1-5 zetwal) | avis en base | garde RLS : l'avis passe (achat réel) |

**Règle d'or pendant le test : tout passe par l'app.** Si quelqu'un est bloqué,
on note le blocage, on aide à trouver le bouton, on ne contourne jamais par un
arrangement hors app (sinon le test ne prouve rien).

---

## 4. Mesures, quoi regarder, où

Les timestamps sont déjà en base (`paid_at`, `verified_at`, `ready_at`,
`delivered_at`, `released_at`). Requête de suivi (MCP, lecture seule) :

```sql
select id, product_title, status, total_amount, fee_amount, net_amount,
  created_at,
  paid_at      - created_at  as t_commande_vers_paiement,
  verified_at  - paid_at     as t_verif_admin,
  ready_at     - verified_at as t_preparation,
  delivered_at - ready_at    as t_livraison_otp,
  released_at  - delivered_at as t_liberation
from public.orders
order by created_at desc limit 10;
```

**Quantitatif (cibles pilote) :**
- Funnel sans trou : chaque commande atteint `released` ou un état expliqué
  (`cancelled`/`disputed` documenté). Zéro commande coincée > 48h sans action.
- `verified_at - paid_at` < 1h (réactivité admin réaliste ?).
- `released_at - delivered_at` < 24h (le vendeur voit son argent vite, c'est
  ça qui construit la confiance).
- `seller_otp_attempts` ≤ 2 par commande.
- `error_logs` : zéro nouvelle erreur applicative pendant les transactions
  (`select source, message, count(*) from error_logs where created_at > <début pilote> group by 1,2`).
- `escrow_attention_orders` vide en fin de pilote.

**Qualitatif (journal de bord, une entrée par transaction) :**
date, vendeur, acheteur, montant, durée totale, frictions verbatim (mots exacts),
moments d'hésitation, questions posées, verdict du vendeur en une phrase
(« èske w ta refè l ak yon vrè kliyan ? »).

---

## 5. Plan d'incident, si ça casse à l'étape…

| Étape | Symptôme | Réaction |
|---|---|---|
| 2 | L'acheteur a payé mais la ref ne passe pas / erreur app | Ne PAS redemander de payer. Admin vérifie MonCash ; si l'argent est là, avancer manuellement via le panel admin (la RPC autorise l'admin) + noter le bug. |
| 3 | Référence introuvable sur MonCash | Attendre 30 min (délais Digicel), re-vérifier ; sinon rembourser l'acheteur et noter. |
| 6 | OTP refusé alors qu'il est bon | STOP remise du produit. ≥5 essais = litige auto → résolution admin. Noter l'écran exact. |
| 7 | Payout MonCash impossible (numéro invalide, plafond) | Ne pas marquer `released` tant que l'argent n'est pas parti. Corriger le numéro avec le vendeur, réessayer. |
| Tout | Litige ouvert | C'est un SUCCÈS de test du rail litige : dérouler la résolution (`Ba vandè a` / `Ranbouse achtè`) et chronométrer. |
| Tout | Bug bloquant app | Screenshot + heure + compte → Alita reproduit sur le vrai fichier, fix, redéploie ; la transaction reprend où elle était (les états sont en base). |

**Budget risque assumé** : au pire, l'admin rembourse l'acheteur de sa poche
(montants ≤ 2 000 HTG). C'est le coût du test réel, il est borné.

---

## 6. Critères de sortie

**Pilote réussi si :**
- ≥ 3 transactions `released` (ou litige résolu proprement), sur ≥ 2 vendeurs
  différents et ≥ 2 acheteurs différents ;
- zéro commande coincée sans explication ;
- zéro contournement hors app ;
- les vendeurs répondent « wi » à « èske w ta refè l ak yon vrè kliyan ? ».

**Alors** : passer au closed testing Google Play avec ces mêmes vendeurs comme
premiers testeurs, et SEULEMENT ensuite ouvrir l'acquisition de vendeurs.

**Pilote à rejouer si** : un rail a cassé (fix puis re-test du rail), ou un
vendeur a dû être assisté à chaque étape (problème d'UX à traiter avant
d'élargir).

---

## 7. Rôles pendant le pilote

- **Thrasher** : recrutement, onboarding en personne, rôle admin (vérif
  paiements, payouts, litiges), décisions d'argent. Toutes les actions d'argent
  restent humaines.
- **Alita** : suivi lecture seule (requêtes §4), fix des bugs remontés,
  journal de bord dans `HISTORY.md`, mise à jour de l'audit et de ce protocole
  après chaque transaction témoin.
