# Audit chemin-critique vers le pilote

> Critère de succès (décision Thrasher, 2026-07-12) : **une transaction réelle
> de bout en bout réussie**, commande → escrow → paiement → livraison → OTP →
> libération des fonds → avis. Pas de démo, pas d'acquisition de masse. Premier
> test = pilote fermé, 2-3 vrais vendeurs contrôlés.
>
> Audit réalisé sur le vrai code (`index.html`) + la vraie base Supabase
> (projet `htxfwxldzaocuwezzbom`), en lecture seule. Dernière mise à jour :
> 2026-07-17.

## Le constat central

**Le pilote n'est PAS bloqué par les credentials MonCash / l'API Digicel.**
Le rail argent est entièrement **manuel** aujourd'hui :

1. L'acheteur envoie MonCash au numéro admin (`app_settings.admin_moncash_number`
   = `50936803970`, frais plateforme 3%).
2. L'acheteur colle la référence → l'admin la vérifie à la main.
3. À la livraison, le vendeur valide l'OTP à 6 chiffres de l'acheteur.
4. L'admin libère et **envoie MonCash au vendeur à la main** (le payout logiciel
   est un stub ; le toast dit « transfere manyèlman via MonCash »).

En prod, **3 commandes ont déjà atteint `released`**. L'API Digicel ne sert
qu'à *automatiser* ce flux plus tard ; elle n'est pas requise pour qu'une
transaction aboutisse au pilote.

## Tableau rouge / jaune / vert

| Rail | État | Détail |
|---|---|---|
| 1. Escrow (RPC `advance_order_status`) | 🟢 + 🔴 | RPC solide : verrou `FOR UPDATE`, idempotence, blocage des états finaux (`completed`/`refunded`/`cancelled`), matrice de transitions par rôle, timestamps, audit `admin_actions`. **Bloqueur** : faille RLS UPDATE (voir plus bas). |
| 2. Paiement MonCash | 🟡 | Manuel = fonctionne E2E. `moncashSendPayout` = stub simulé. Automation Digicel reportée (non requise au pilote). |
| 3. Machine à états commandes | 🟢 | Chaîne complète câblée, tout via RPC. Détail cosmétique : `completed` jamais atteint (l'avis n'avance pas la commande ; elle termine à `released`, argent déjà réglé). L'état `picked_up` du pipeline est court-circuité (`ready_for_pickup` → `otp_confirmed`). |
| 4. Litiges | 🟢 | `submitDispute` stocke raison + détails, notifie admin + autre partie ; auto-litige après 5 OTP ratés ; alerte anti-fraude si vendeur ≥2 litiges/30j ; résolution release/refund. Pas de table dédiée : `status='disputed'` + `admin_note` suffit. |
| 5. Notifications role-aware | 🟢 | `notify()` / `notifyAdmins()` sur tous les événements argent ; realtime `user_id=eq.<me>`. Mineur : `submitRating` fait un insert notif direct au lieu de `notify()`. |
| 6. Vérification vendeur | 🟢 + 🟡 | Voie CIN/Paspò → validation admin manuelle = **fonctionne** (1 approuvée, 1 rejetée en réel). OTP SMS : **0 téléphone vérifié** → provider SMS non configuré (voir action ci-dessous). |

**Bonus 🟢** : les avis exigent un vrai achat (RLS `reviews_insert_buyer` avec
`EXISTS` sur une commande livrée), pas de faux avis. Observabilité escrow
présente (`escrow_overview`, `escrow_attention_orders`, `escrow_dispatch_alerts`,
`escrow_alert_log`, `admin_actions`). Catalogue : 4 profils, 1 vendeur, 1 produit
actif = normal (comptes de test, pré-pilote).

## 🔴 Bloqueur à traiter avant de l'argent réel

**Les policies RLS `UPDATE` sur `orders` laissaient tout participant
(acheteur/vendeur) modifier une commande en direct**, contournant la machine à
états. Vérifié : aucun trigger de garde (seuls `trg_orders_updated` = timestamp
et `trg_grant_referral_reward` = récompense parrainage). Un client malveillant
pouvait donc flipper `status` (ex. `payment_verified` sans payer) et même
déclencher le parrainage.

Le client officiel n'écrit jamais `orders` en direct (tout via RPC SECDEF), donc
le correctif est sûr.

**Correctif** : migration `supabase/migrations/20260717140000_harden_orders_update_rls.sql`
- retire les policies UPDATE participants, garde un override admin, nettoie une
policy SELECT dupliquée. À revoir + merger (changement RLS).

## Actions restantes

- [ ] **Merger le durcissement RLS** (migration ci-dessus). Seul vrai bloqueur.
- [ ] **Configurer un provider SMS** dans Supabase → Auth → Providers → Phone
      (Twilio / Vonage / MessageBird) pour activer l'OTP téléphone vendeur
      (décision : SMS OTP obligatoire au pilote). Coût + config dashboard côté
      Thrasher. Le code est prêt (`smsRequestOtp` / `smsVerifyOtp`) et dégrade
      proprement si le provider manque. Note : rendre l'OTP *bloquant* pour
      devenir vendeur demandera un petit garde `phone_verified` en plus (suivi).
- [ ] **Recruter 2-3 vrais vendeurs contrôlés** pour le pilote fermé (aligné avec
      le closed testing Google Play).
- [ ] (Optionnel) Polir : avancer à `completed` sur l'avis ; passer `submitRating`
      par `notify()`.

## Ce qui est déjà vert et ne bloque pas

Escrow RPC, machine à états, litiges, notifications, vérification par pièce
d'identité, sécurité des avis, observabilité. Le flux manuel MonCash permet une
transaction réelle E2E dès aujourd'hui, une fois le durcissement RLS mergé.
