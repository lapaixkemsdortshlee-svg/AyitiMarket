# Ekomat — Refonte de la page produit (spécification d'implémentation)

**Destinataire :** Alita (Claude Code)
**Auteur de la demande :** Thrasher
**Date :** 2026-07-29
**Statut :** spec figée, prête à exécution par lots

---

## 0. Comment utiliser ce document

Alita, tu ne codes rien avant d'avoir terminé la **Phase 0 (audit)** en section 3 et d'avoir remonté tes constats à Thrasher.

Ce document est une spec, pas une suggestion. Quand une décision est marquée **[DÉCIDÉ]**, tu l'appliques sans la rediscuter. Quand elle est marquée **[À CONFIRMER]**, tu poses la question avant d'écrire la ligne de code concernée.

Ordre d'exécution imposé : Phase 0 → Lot 1 → Lot 2 → Lot 3 → Lot 4. Tu ne démarres pas un lot tant que le précédent n'a pas passé ses critères d'acceptation (section 10).

Chaque lot se termine par un commit propre et une démo fonctionnelle. Pas de branche qui traîne trois jours avec du code mort dedans.

---

## 1. Contexte et contraintes non négociables

### 1.1 Le produit

Ekomat est une marketplace multi-vendeurs mobile-first pour le marché haïtien et la diaspora. Le tunnel est : commande → escrow → paiement MonCash → livraison → confirmation OTP 6 chiffres → libération des fonds → avis.

### 1.2 Contraintes globales — s'appliquent à toutes les tâches

| # | Contrainte | Détail |
|---|---|---|
| C1 | **Mobile-first** | Le design de référence est desktop. Tu conçois en 360–430 px de large d'abord. Le desktop est une adaptation, pas l'inverse. |
| C2 | **Kreyòl d'abord** | Tous les libellés UI en Kreyòl. Français en secours uniquement si une clé de traduction manque. Pas d'anglais visible côté acheteur. |
| C3 | **Zéro régression** | Ce qui existe et fonctionne n'est ni supprimé ni réécrit. Tu étends, tu ne refais pas. |
| C4 | **Rétrocompatibilité totale** | Les produits déjà en base doivent continuer à s'afficher et à s'acheter sans aucune variante définie. Toute nouvelle colonne est nullable ou a un défaut. |
| C5 | **Le client n'envoie jamais un prix** | Le montant d'une commande est calculé côté serveur (RPC), à partir de la base. Toujours. |
| C6 | **Réseau contraint** | Budget page produit : < 400 Ko au premier rendu, hors images au-delà de la première. |
| C7 | **Pas de dépendance nouvelle** | Aucune librairie ajoutée sans validation explicite de Thrasher. L'app est un PWA mono-fichier sur Supabase. |
| C8 | **RLS d'abord** | Toute nouvelle table a ses policies RLS écrites dans la même migration que le `CREATE TABLE`. Jamais après. |
| C9 | **Migrations réversibles** | Chaque migration a son `down`. Testée sur une copie avant production. |
| C10 | **Zone monétaire** | Prix en HTG. Pas de conversion affichée sans validation. |

---

## 2. Périmètre

### 2.1 Dans le périmètre

- Refonte de la structure et du design de la page produit acheteur
- Système de variantes produit (couleur, taille, et autres axes selon catégorie)
- Fiche technique / attributs produit avec option personnalisée
- Déclaration de garantie par le vendeur
- Passage de 4 à 8 images produit
- Bloc avis clients sur la page produit
- Bloc produits similaires
- Extension du formulaire vendeur pour alimenter tout ce qui précède
- Propagation des variantes dans panier → commande → escrow

### 2.2 Hors périmètre — et pourquoi

| Exclu | Raison |
|---|---|
| Refonte du feed / de la home | Non demandé, et ça multiplierait la surface de régression. |
| Moteur de recommandation | YAGNI. Une heuristique « même catégorie » suffit pour des années. |
| Filtres par couleur/taille dans la recherche | Lot ultérieur. La donnée sera prête, l'UI de filtre non. |
| Gestion de stock multi-entrepôt | Hors sujet pour ce marché. |
| Comparateur de produits | Aucun signal de besoin. |
| Vidéo produit | À reparler après le pilote. Coût réseau prohibitif aujourd'hui. |

---

## 3. Phase 0 — Audit obligatoire avant toute ligne de code

**Tu ne codes pas avant d'avoir répondu à ces questions par écrit à Thrasher.**

Thrasher a été explicite : *« si li gn youn deja pa ajoute li »*. Plusieurs de ces briques existent probablement déjà. Ton travail commence par un inventaire, pas par un `CREATE TABLE`.

### 3.1 Inventaire à produire

- [ ] **Schéma `products`** — liste exhaustive des colonnes actuelles. Y a-t-il déjà un champ `attributes`, `metadata`, `options`, `specs` en JSONB ?
- [ ] **Images** — comment sont-elles stockées aujourd'hui ? Tableau de URLs, table dédiée, bucket Supabase Storage ? Où est codée en dur la limite de 4 ?
- [ ] **Avis** — le système d'avis existe-t-il déjà (mémoire : le tunnel se termine par un avis) ? Table, schéma, où est-il affiché aujourd'hui ? **Si oui : tu ne le reconstruis pas, tu le remontes sur la page produit.**
- [ ] **Catégories** — structure actuelle. Plate ou arborescente ? Combien de catégories ? Y a-t-il déjà des métadonnées par catégorie ?
- [ ] **Panier** — schéma de la table panier. Quelle est la contrainte d'unicité actuelle (probablement `UNIQUE(user_id, product_id)`) ? **C'est le point qui va casser.**
- [ ] **Commandes** — schéma `orders` / `order_items`. Le prix est-il déjà figé (snapshot) au moment de la commande, ou lu en direct depuis `products` ?
- [ ] **RPC escrow** — liste des fonctions, et laquelle calcule le montant. Signature exacte.
- [ ] **Formulaire vendeur** — où est le code du formulaire de création/édition produit ? Combien d'étapes ?
- [ ] **Design tokens** — existe-t-il déjà des variables de couleur, d'espacement, de typo ? Récupère-les. La palette Ekomat est rouille / teal / crème.

### 3.2 Livrable de la Phase 0

Un court rapport en Markdown répondant aux 9 points, avec pour chaque brique : **existe / n'existe pas / existe partiellement**, et le chemin du fichier concerné. Plus une liste des ruptures anticipées.

---

## 4. Modèle de données

### 4.1 Principe directeur

Ne modélise pas « couleur » et « taille » comme deux colonnes. Modélise des **axes de variantes définis par catégorie**. C'est ce que Thrasher a intuité avec le point D (« key attribution avec option custom ») — on le formalise.

Raison : S/M/L/XL/XXL ne vaut que pour le vêtement. Les chaussures ont besoin de 36–46. Un téléphone a besoin de 64/128/256 Go. Une seule colonne `size` te bloque dans six mois.

### 4.2 Palette de couleurs curatée **[DÉCIDÉ — contre la demande initiale]**

**La demande initiale était un sélecteur RGB libre avec minimum 7 couleurs. On ne fait pas ça.**

Raison : un picker libre produit 40 nuances de bleu incohérentes selon les vendeurs, rend tout filtrage futur impossible, et détruit la cohérence visuelle des pastilles. La loi de Hick dit aussi qu'un choix infini augmente le temps de décision et le taux d'abandon.

À la place : **table de référence fermée**, le vendeur pioche dedans.

```sql
CREATE TABLE color_reference (
  code        text PRIMARY KEY,      -- 'noir', 'ble_maren', 'wouj'
  label_ht    text NOT NULL,         -- 'Nwa', 'Ble maren', 'Wouj'
  label_fr    text NOT NULL,
  hex         text NOT NULL,         -- '#000000'
  hex_secondary text,                -- pour bicolore / dégradé
  sort_order  int  NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true
);
```

Contenu initial : environ 18 entrées couvrant le besoin réel du marché.

`Nwa`, `Blan`, `Gri`, `Gri klè`, `Ble maren`, `Ble syèl`, `Wouj`, `Woz`, `Vèt`, `Vèt fonse`, `Jòn`, `Zoranj`, `Mawon`, `Beige`, `Vyolèt`, `Dore`, `Ajan`, `Milticolor`.

**Échappatoire unique :** une valeur `lot` (Autre) qui autorise le vendeur à saisir un libellé texte libre, affichée sans pastille mais avec le libellé. Un seul niveau d'échappatoire, pas plus.

**Rendu de la pastille :** cercle 32 px, bordure 1 px `rgba(0,0,0,.12)` pour que le blanc reste visible sur fond clair, anneau de sélection 2 px à la couleur d'accent Ekomat. Coche à l'intérieur si la couleur est foncée, pour l'accessibilité. Jamais de pastille sans son libellé texte à côté — un daltonien doit pouvoir acheter.

### 4.3 Axes de variantes par catégorie

```sql
CREATE TABLE category_variant_axis (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id    uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  axis_key       text NOT NULL,          -- 'color' | 'size' | 'capacity' | 'material'
  label_ht       text NOT NULL,          -- 'Koulè', 'Gwosè', 'Kapasite'
  input_type     text NOT NULL,          -- 'swatch' | 'chip' | 'select'
  value_source   text NOT NULL,          -- 'color_reference' | 'enum' | 'free'
  allowed_values jsonb,                  -- ['S','M','L','XL','XXL'] si value_source='enum'
  sort_order     int NOT NULL DEFAULT 0,
  UNIQUE (category_id, axis_key)
);
```

Exemples de seed :

| Catégorie | axis_key | label_ht | input_type | allowed_values |
|---|---|---|---|---|
| Rad (vêtements) | `color` | Koulè | swatch | (color_reference) |
| Rad | `size` | Gwosè | chip | `["S","M","L","XL","XXL"]` |
| Soulye | `color` | Koulè | swatch | (color_reference) |
| Soulye | `size` | Gwosè | chip | `["36","37","38","39","40","41","42","43","44","45","46"]` |
| Telefòn | `color` | Koulè | swatch | (color_reference) |
| Telefòn | `capacity` | Kapasite | chip | `["64GB","128GB","256GB","512GB"]` |
| Elektwonik | `color` | Koulè | swatch | (color_reference) |

**Tous les axes sont facultatifs pour le vendeur.** Un produit sans aucune variante définie reste parfaitement valide et achetable. C'est la contrainte C4.

### 4.4 Variantes produit

```sql
CREATE TABLE product_variant (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id     uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  axis_values    jsonb NOT NULL,        -- {"color":"ble_maren","size":"L"}
  sku            text,
  stock_status   text NOT NULL DEFAULT 'in_stock',  -- 'in_stock' | 'out_of_stock'
  stock_qty      int,                   -- nullable : suivi quantitatif optionnel
  price_override numeric(12,2),         -- NULL = prix du produit
  image_id       uuid,                  -- image à afficher quand ce coloris est choisi
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, axis_values)
);

CREATE INDEX idx_product_variant_product ON product_variant(product_id) WHERE is_active;
```

#### Décision critique sur le prix **[DÉCIDÉ]**

**Par défaut, le prix est au niveau du produit, pas de la variante.** `price_override` reste NULL dans l'écrasante majorité des cas.

Raison : 7 couleurs × 5 tailles = 35 combinaisons. Demander à un vendeur haïtien de remplir 35 prix sur un téléphone, c'est garantir que la fonctionnalité ne sera jamais utilisée. Le prix par variante est une option avancée, cachée derrière un interrupteur « Pri diferan pou chak varyant ».

Même logique pour le stock : par défaut, une variante est simplement **disponible ou non**. La quantité (`stock_qty`) est optionnelle.

#### Génération des combinaisons

Le vendeur ne saisit pas 35 lignes. Il coche ses couleurs, coche ses tailles, et l'interface génère la matrice avec **tout disponible par défaut**. Il décoche ensuite les combinaisons qu'il n'a pas. C'est de la soustraction, pas de l'addition — trois fois moins de gestes.

### 4.5 Attributs / fiche technique

```sql
CREATE TABLE product_attribute (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  attr_key     text,          -- clé normalisée si issue d'un preset
  label_custom text,          -- libellé libre si attribut personnalisé
  value_text   text NOT NULL,
  sort_order   int NOT NULL DEFAULT 0,
  CHECK (attr_key IS NOT NULL OR label_custom IS NOT NULL)
);
```

**Presets par catégorie** — ce sont les « boutons auto » demandés au point E. Le vendeur tape un bouton, la ligne s'ajoute pré-remplie avec le libellé, il n'a plus qu'à saisir la valeur.

| Catégorie | Presets proposés |
|---|---|
| Rad | Matyè, Antretyen, Koup, Peyi fabrikasyon |
| Soulye | Matyè, Semèl, Otè talon, Fèmti |
| Telefòn | Ekran, Batri, Kamera, RAM, Sistèm, Rezo |
| Elektwonik | Pisans, Konneksyon, Otonomi, Garanti fabrikan, Sa ki nan bwat la |
| Bote | Volim, Tip po, Engredyan prensipal, Dat ekspirasyon |

Plus, dans tous les cas, un bouton **« + Ajoute pa w »** qui crée une ligne libellé libre + valeur libre. C'est le « custom » du point D.

**Limite : 12 attributs par produit.** Au-delà, personne ne lit, et la page s'allonge pour rien.

### 4.6 Garantie **[DÉCIDÉ — encadrement obligatoire]**

La demande initiale était que le vendeur ajoute une garantie visible par l'acheteur. On le fait, mais **jamais en texte libre non encadré**.

Raison : si un vendeur écrit « garanti 2 an » et ne l'honore pas, l'acheteur ne s'en prend pas au vendeur, il s'en prend à Ekomat. Tu transformes une promesse de tiers en passif de plateforme.

```sql
ALTER TABLE products
  ADD COLUMN warranty_type text NOT NULL DEFAULT 'none',
  -- 'none' | '7d' | '30d' | '3m' | '6m' | '1y' | '2y'
  ADD COLUMN warranty_note text;  -- 140 caractères max, ce que couvre la garantie
```

**Règle d'affichage obligatoire :** dès qu'une garantie est affichée, une mention est affichée juste en dessous, non masquable, en taille réduite :

> *Garanti sa a bay pa vandè a, se pa Ekomat ki bay li.*

**Snapshot obligatoire :** au moment de la commande, `warranty_type` et `warranty_note` sont copiés dans `order_items`. Sinon le vendeur peut modifier sa garantie après la vente, et l'acheteur n'a plus aucune preuve.

### 4.7 Médias — passage de 4 à 8 images

**Ne te contente pas de changer un `4` en `8`.** C'est un sujet réseau, pas un sujet de constante.

Exigences :

1. **Compression côté client avant upload.** Redimensionnement à 1400 px sur le côté long, conversion WebP, qualité 82. Cible : < 250 Ko par image. Utilise `canvas` natif, pas de librairie.
2. **Trois dérivés stockés par image** : `thumb` (160 px), `medium` (720 px), `full` (1400 px). Le feed consomme `thumb`, la galerie `medium`, le zoom `full`.
3. **Chargement** : seule l'image 1 est chargée en `eager` avec `fetchpriority="high"`. Les 7 autres en `loading="lazy"`. Placeholder de couleur dominante pendant le chargement, pour éviter le décalage de mise en page.
4. **Ordre réorganisable** par le vendeur — glisser-déposer, ou à défaut des flèches haut/bas (plus fiable au doigt).
5. **La première image est la couverture.** Explicite dans l'UI vendeur.
6. **Association couleur ↔ image** : le vendeur peut lier une image à une variante de couleur. Quand l'acheteur choisit « Wouj », la galerie saute à l'image rouge. Détail à faible coût, effet fort sur la perception de sérieux.
7. **Minimum recommandé, pas obligatoire** : afficher au vendeur un indicateur « 3/8 foto — pwodwi ak 5+ foto vann pi vit ». Nudge, pas blocage.

### 4.8 Propagation panier → commande → escrow

**C'est la partie la plus risquée de tout le chantier. Traite-la en premier, pas en dernier.**

L'Image 4 fournie par Thrasher le montre explicitement : chaque ligne du panier affiche `Color : ... | Size : ...`. La variante doit survivre à tout le tunnel.

#### Ruptures à traiter

1. **Contrainte d'unicité du panier.** Aujourd'hui, probablement `UNIQUE(user_id, product_id)`. Il faut `UNIQUE(user_id, product_id, variant_id)`. Le même produit en L et en XL, ce sont deux lignes distinctes. Migration à écrire avec soin sur les paniers existants (`variant_id` NULL pour tout l'existant).

2. **Snapshot à la commande.** `order_items` doit stocker un instantané complet, pas une référence :

```sql
ALTER TABLE order_items
  ADD COLUMN variant_id uuid,             -- référence, peut devenir orpheline
  ADD COLUMN variant_snapshot jsonb,      -- copie figée, source de vérité pour l'affichage
  ADD COLUMN warranty_snapshot jsonb;
```

Exemple de `variant_snapshot` :

```json
{
  "color": { "code": "ble_maren", "label_ht": "Ble maren", "hex": "#1B2A4A" },
  "size":  { "value": "L", "label_ht": "Gwosè L" }
}
```

Raison : si le vendeur supprime ou renomme la variante après la vente, la commande, le reçu et l'écran de livraison doivent toujours afficher ce qui a été réellement acheté. Sans snapshot, tu auras des litiges que tu ne pourras pas arbitrer — dans un système à escrow, c'est rédhibitoire.

3. **Calcul du montant escrow.** La RPC de création de commande lit le prix ainsi : `COALESCE(variant.price_override, product.price)`. Elle ne fait jamais confiance au client (contrainte C5). Le montant escrow découle du total serveur.

4. **Vérification de disponibilité au moment de la commande**, pas seulement à l'ajout au panier. Un article peut passer en rupture entre les deux. Message d'erreur explicite en Kreyòl, avec proposition de retirer la ligne.

5. **Écran de livraison / OTP.** Le livreur et l'acheteur doivent voir la variante. Sinon, litige garanti sur « ce n'est pas la taille que j'ai commandée ».

### 4.9 RLS

- `color_reference` et `category_variant_axis` : lecture publique, écriture réservée au rôle admin.
- `product_variant` et `product_attribute` : lecture publique si le produit parent est publié ; écriture réservée au vendeur propriétaire du produit.
- **Vérifie que la policy d'écriture remonte bien jusqu'au propriétaire du produit parent**, pas seulement à un `auth.uid()` quelconque. C'est la faille classique sur les tables filles.

---

## 5. Spécification UI — page produit acheteur (mobile-first)

### 5.1 Référence visuelle et ce qu'il faut en retenir

L'Image 5 sert de référence de **structure et d'ordre des blocs**. Elle ne sert pas de référence de mise en page.

**Ce qu'on garde :** l'ordre des sections (galerie → identité → prix → options → CTA → confiance → détails → avis → FAQ → similaires).

**Ce qu'on rejette explicitement :**

| Élément de la référence | Décision | Raison |
|---|---|---|
| Second CTA « BUY NOW » | **Supprimé** | Deux CTA primaires fragmentent le tunnel et t'obligent à maintenir deux chemins de paiement dans un flux escrow. Un seul CTA. |
| Badges « 30-Day Money Back », « 2-Year Warranty » | **Remplacés** | Ekomat ne peut pas honorer ces promesses. Afficher une garantie fausse dans un marché à déficit de confiance est le plus mauvais choix possible. |
| Mise en page 2 colonnes | **Reflowée** | Ekomat est un PWA mobile-first. Colonne unique en dessous de 768 px. |
| Barre de navigation desktop | **Non repris** | L'app a déjà sa navigation. Contrainte C3. |

### 5.2 Deux blocs absents des références — et pourtant les plus importants

L'Image 5 est un site mono-marque. Ekomat est une marketplace. Les deux questions qui bloquent réellement un achat en Haïti n'y figurent pas :

**Bloc vendeur.** *À qui j'achète, et est-ce que je peux lui faire confiance ?* Nom de la boutique, badge « Verifye » si l'identité est validée, note vendeur, nombre de ventes, délai de réponse moyen, lien vers la boutique. Sur une marketplace, c'est souvent l'élément qui décide de l'achat, davantage que la fiche produit.

**Bloc livraison.** *Quand, comment, combien ?* Zone de livraison couverte, délai estimé, frais estimés, mention moto si pertinent. En Haïti, l'incertitude sur la livraison est un frein d'achat majeur. Le laisser hors de la page, c'est renvoyer l'acheteur poser la question en chat — et perdre la vente.

### 5.3 Structure de la page, bloc par bloc

Ordre imposé en mobile, de haut en bas :

**1. Galerie**
Carrousel plein cadre, ratio 1:1. Défilement horizontal au doigt. Compteur `3/8` en surimpression, coin bas droit. Vignettes défilantes sous le carrousel à partir de 4 images. Tap sur l'image → visionneuse plein écran avec zoom par pincement. Badges en surimpression coin haut gauche : `Nouvo` si < 14 jours, `-33%` si prix barré présent. Maximum deux badges, jamais trois.

**2. Titre + sous-titre**
Titre : 2 lignes maximum, ellipse au-delà. Sous-titre optionnel : 1 ligne, gris moyen.

**3. Note et avis**
`★ 4.8 (128 avi)` — cliquable, ancre vers la section avis. **Masqué intégralement si zéro avis.** Ne jamais afficher « 0 avi » ni cinq étoiles vides : c'est un signal négatif là où l'absence est neutre.

**4. Prix**
Prix actuel en gros et en gras. Prix barré à côté, plus petit et en gris, **uniquement s'il correspond à un prix réellement pratiqué auparavant**. Badge d'économie `Ekonomi 3 000 HTG`. Un ancrage inventé est détectable et détruit la crédibilité.

**5. Vendeur**
Avatar, nom de boutique, badge `Verifye`, note, nombre de ventes. Ligne cliquable vers la boutique.

**6. Sélecteur de couleur** *(si l'axe existe pour la catégorie et que le vendeur l'a renseigné)*
Libellé dynamique : `Koulè : Ble maren`. Pastilles 32 px, espacement 12 px, retour à la ligne automatique. Pastille grisée avec barre oblique si toutes les combinaisons de cette couleur sont en rupture.

**7. Sélecteur de taille** *(idem)*
Puces rectangulaires, hauteur minimum 44 px (contrainte tactile). Lien `Gid gwosè` aligné à droite du libellé. Puce barrée si rupture. Tap sur une puce en rupture → message `Gwosè sa a fini` plutôt qu'une absence de réaction.

**8. État du stock**
Affiché uniquement si `stock_qty` est renseigné et inférieur à 5 : `Rete 2 sèlman`. **Jamais de fausse rareté.** Si le stock n'est pas suivi, on n'affiche rien.

**9. CTA principal**
Un seul : `Mete nan panye`. Pleine largeur, hauteur 52 px, couleur d'accent Ekomat. Devient collant en bas d'écran dès que l'utilisateur dépasse le bloc. La barre collante rappelle le prix à gauche et le CTA à droite.

État désactivé si un axe obligatoire n'est pas sélectionné, avec message d'aide `Chwazi yon gwosè` — et non un bouton inerte sans explication.

**10. Bloc confiance Ekomat**
Grille 2×2, icônes SVG. **Uniquement des affirmations que la plateforme peut tenir :**

- `Lajan w pwoteje` — Escrow jiskaske ou konfime livrezon
- `Konfimasyon ak kòd` — 6 chif pou valide resepsyon
- `Peman MonCash` — Sekirize
- `Vandè verifye` — Idantite kontwole

C'est un argumentaire plus fort que n'importe quel badge générique, parce qu'il est vrai et spécifique au marché.

**11. Livraison**
Zone, délai estimé, frais estimés. Si l'adresse de l'utilisateur est connue, personnalise. Sinon, valeur par défaut par zone.

**12. Description**
Texte du vendeur. Repliée au-delà de 4 lignes avec un bouton `Wè plis`.

**13. Fiche technique**
Liste clé/valeur en deux colonnes. Accordéon replié par défaut si plus de 6 attributs.

**14. Garantie** *(si déclarée)*
Icône bouclier, durée, note du vendeur, et la mention obligatoire de responsabilité (section 4.6).

**15. Avis clients**
Note moyenne, répartition par étoiles, puis les 3 avis les plus récents en cartes. Lien `Wè tout avi yo`. Affiche en priorité les avis **avec commentaire**, pas seulement une note. **Bloc entièrement masqué si zéro avis.**

**16. Produits similaires**
Carrousel horizontal. **Masqué si moins de 4 candidats.** Heuristique : même catégorie, produit courant exclu, publié, en stock, trié par ventes puis par récence. Pas de moteur de recommandation.

**17. Barre CTA collante**
Prix + `Mete nan panye`. Apparaît au scroll, disparaît quand le CTA principal est de nouveau visible.

### 5.4 États à traiter systématiquement

Pour chaque bloc, tu implémentes les quatre états. Un bloc qui n'a que son état nominal est un bloc non terminé.

| État | Traitement |
|---|---|
| Chargement | Squelette aux bonnes dimensions. Jamais de spinner centré sur toute la page. |
| Vide | Bloc masqué, pas de message « aucune donnée ». |
| Erreur | Message court en Kreyòl + bouton `Eseye ankò`. |
| Rupture | Produit visible, CTA désactivé, message explicite, bouton `Avèti m lè li tounen` si la fonctionnalité existe. |

---

## 6. Spécification UI — formulaire vendeur

**Le formulaire vendeur détermine si toute cette spec sert à quelque chose.** Si le remplissage est pénible, les fiches resteront vides et la page produit sera un beau conteneur sans contenu.

### 6.1 Principes

1. **Tout est facultatif sauf le minimum vital** (titre, prix, catégorie, 1 image). Aucun nouveau champ obligatoire.
2. **Progressif.** Les variantes n'apparaissent que si le vendeur active `Pwodwi sa a gen plizyè opsyon`.
3. **Adapté à la catégorie.** Les axes proposés découlent de `category_variant_axis`. Un vendeur de téléphones ne voit jamais S/M/L/XL/XXL.
4. **Sauvegarde brouillon automatique.** Sur réseau instable, perdre un formulaire à moitié rempli fait abandonner définitivement.
5. **Indicateur de complétude.** Barre de progression + `Fich ou konplè a 70 %`. Motivation par la boucle ouverte, sans blocage.

### 6.2 Séquence d'écrans

```
1. Enfòmasyon debaz     → titre, catégorie, prix, description
2. Foto                 → jusqu'à 8, réorganisables, la 1re = couverture
3. Opsyon               → [interrupteur] activer les variantes
                          ├─ cocher les couleurs (palette)
                          ├─ cocher les tailles/axes de la catégorie
                          └─ matrice générée, tout disponible par défaut,
                             le vendeur décoche ce qu'il n'a pas
4. Detay teknik         → boutons preset par catégorie + « + Ajoute pa w »
5. Garanti              → menu déroulant + note courte optionnelle
6. Livrezon             → zones desservies, délai
7. Apèsi                → aperçu exact de la page acheteur avant publication
```

L'étape 7 n'est pas cosmétique. Voir le rendu final avant publication est ce qui pousse un vendeur à revenir compléter les étapes qu'il avait sautées.

---

## 7. Psychologie et CRO appliqués

Chaque principe ci-dessous est rattaché à un bloc concret. Aucun n'est décoratif, et aucun ne repose sur une information fausse.

| Principe | Application | Garde-fou |
|---|---|---|
| **Réduction du risque perçu** | Bloc confiance escrow + OTP en position haute, juste sous le CTA | C'est le levier dominant sur ce marché. En Haïti, la peur de se faire arnaquer pèse plus lourd que le désir du produit. Ce bloc fait plus pour la conversion que n'importe quel travail sur le prix. |
| **Preuve sociale** | Note, nombre d'avis, nombre de ventes vendeur | Masqué si nul. Un « 0 avi » fait plus de mal que l'absence de bloc. |
| **Ancrage** | Prix barré + badge d'économie | Uniquement si le prix antérieur est réel. Un ancrage fabriqué se repère et détruit la confiance. |
| **Rareté honnête** | `Rete 2 sèlman` | Uniquement si le stock est réellement suivi. Aucune rareté artificielle. |
| **Loi de Hick** | Palette fermée de 18 couleurs au lieu d'un RGB libre | Moins d'options = décision plus rapide. Argument principal contre le picker libre. |
| **Charge cognitive** | Un seul CTA, accordéons sur les blocs longs | Motif du rejet du « BUY NOW ». |
| **Effet Von Restorff** | La couleur d'accent est réservée au CTA | Si trois éléments partagent la couleur du bouton, plus rien ne ressort. |
| **Effet de dotation** | 8 photos, zoom, image liée au coloris | Plus l'acheteur se projette dans la possession, plus il convertit. C'est la vraie justification du passage de 4 à 8 images. |
| **Aversion à la perte** | `Lajan w pwoteje jiskaske ou konfime` | Formulé comme une protection de ce qu'il a, pas comme un gain. |
| **Fluidité de traitement** | Kreyòl, prix en HTG, vocabulaire de livraison local | Un contenu compris sans effort est perçu comme plus fiable. Ce n'est pas de la traduction, c'est de la conversion. |
| **Objection préemptive** | FAQ produit, guide des tailles, bloc livraison | Chaque question sans réponse sur la page devient soit un message en chat, soit un abandon. |

---

## 8. Contraintes Haïti — à ne pas traiter comme du confort

1. **Budget réseau.** Page produit sous 400 Ko au premier rendu. Une fiche à 8 images non optimisées peut atteindre 20 Mo. C'est un abandon garanti et une facture de stockage.
2. **Coût du stockage.** 8 images × 3 dérivés × N produits. Fais l'estimation avant d'ouvrir la vanne, et remonte-la à Thrasher.
3. **Upload vendeur.** La compression se fait sur le téléphone du vendeur, avant l'envoi. Avec barre de progression et reprise sur échec.
4. **Hors ligne.** Le PWA doit afficher la dernière version consultée d'une fiche quand le réseau tombe, avec un bandeau `Pa gen koneksyon`.
5. **Appareils bas de gamme.** Cible : Android milieu de gamme. Pas d'animation coûteuse, pas d'ombres portées multiples, pas de flou d'arrière-plan.
6. **Langue.** Kreyòl partout côté acheteur. Les libellés d'axes et de couleurs sont stockés en Kreyòl **en base**, pas codés en dur dans le front.

---

## 9. Découpage en lots

### Lot 1 — Fondations données et variantes *(bloquant pour le pilote)*

Contient : `color_reference`, `category_variant_axis`, `product_variant`, migration du panier, snapshot commande, mise à jour de la RPC escrow, sélecteurs couleur/taille sur la page produit, matrice de variantes dans le formulaire vendeur.

**C'est ici qu'est le risque.** Une transaction end-to-end doit repasser avec une variante avant d'aller plus loin.

**[À CONFIRMER auprès de Thrasher]** Ce lot n'est bloquant que si les 2–3 vendeurs du pilote vendent des articles à variantes (vêtements, chaussures). S'ils vendent de l'électronique sans déclinaison, le Lot 1 peut passer après le Lot 2 et le pilote démarre plus tôt.

### Lot 2 — Présentation *(fort impact, faible risque)*

Contient : refonte de la structure de page, galerie 8 images avec pipeline de compression, bloc vendeur, bloc livraison, bloc confiance Ekomat, barre CTA collante, tous les états de chargement/vide/erreur.

Aucun changement de schéma critique. C'est le lot au meilleur rapport effet/risque : il peut être livré indépendamment.

### Lot 3 — Contenu enrichi

Contient : attributs et fiche technique avec presets, garantie, remontée des avis sur la page produit (après audit — probablement existant), guide des tailles.

### Lot 4 — Découverte

Contient : produits similaires, FAQ produit.

À traiter en dernier, et seulement une fois le catalogue suffisamment fourni pour que le bloc ne paraisse pas vide.

---

## 10. Critères d'acceptation

Un lot n'est pas terminé tant que tous les critères ne sont pas vérifiés **manuellement sur un appareil réel**, pas seulement en console.

### Lot 1

- [ ] Un produit existant sans variante s'affiche et s'achète exactement comme avant (non-régression)
- [ ] Un vendeur crée un produit avec 3 couleurs × 3 tailles en moins de 2 minutes sur téléphone
- [ ] L'acheteur ne peut pas ajouter au panier sans avoir choisi tous les axes obligatoires
- [ ] Le même produit en deux tailles produit deux lignes distinctes dans le panier
- [ ] La variante est visible dans : panier, récapitulatif commande, écran vendeur, écran de livraison, confirmation OTP
- [ ] Le montant escrow correspond au prix serveur, jamais à une valeur envoyée par le client
- [ ] Suppression d'une variante après commande : la commande affiche toujours la bonne variante (snapshot)
- [ ] Une variante en rupture est visuellement barrée et non sélectionnable
- [ ] **Une transaction end-to-end complète passe avec un produit à variantes** : commande → escrow → MonCash → livraison → OTP → libération → avis
- [ ] La migration s'exécute et se rejoue en sens inverse sans perte de données

### Lot 2

- [ ] Premier rendu sous 400 Ko, mesuré onglet réseau en 3G simulée
- [ ] Une image uploadée à 6 Mo est compressée sous 250 Ko avant envoi
- [ ] Aucun décalage de mise en page pendant le chargement de la galerie
- [ ] Toutes les cibles tactiles ≥ 44 px
- [ ] Contraste ≥ 4.5:1 sur tout texte, vérifié
- [ ] Aucune couleur communiquée par la seule pastille : le libellé texte est toujours présent
- [ ] Navigation au clavier fonctionnelle sur les sélecteurs
- [ ] Page utilisable en 360 px de large sans défilement horizontal
- [ ] Le bloc confiance ne contient aucune promesse qu'Ekomat ne peut pas honorer

### Lot 3

- [ ] Les presets d'attributs correspondent à la catégorie du produit
- [ ] L'attribut personnalisé fonctionne et se réordonne
- [ ] La garantie affiche systématiquement la mention de responsabilité vendeur
- [ ] La garantie est figée sur la commande
- [ ] Les avis existants sont remontés, non dupliqués

### Lot 4

- [ ] Le bloc « produits similaires » est absent du DOM si moins de 4 candidats
- [ ] Le produit courant ne s'affiche jamais dans ses propres similaires

---

## 11. Anti-specs — ce qu'il ne faut pas faire

- Ne pas ajouter de second CTA de type « Achte kounye a » à côté de « Mete nan panye »
- Ne pas afficher de badge de confiance générique qu'Ekomat ne peut pas tenir
- Ne pas implémenter un sélecteur RGB libre
- Ne pas construire un moteur de recommandation
- Ne pas rendre un champ existant obligatoire
- Ne pas laisser le client transmettre un prix ou un montant
- Ne pas lire le prix ou la garantie en direct depuis `products` pour afficher une commande passée
- Ne pas utiliser d'emoji comme icône — SVG uniquement
- Ne pas mettre de carrousel en défilement automatique
- Ne pas afficher « 0 avi » ou cinq étoiles vides
- Ne pas afficher de compte à rebours ou de rareté non adossés à une donnée réelle
- Ne pas toucher au feed, à la recherche ou au tunnel de paiement dans ces lots
- Ne pas installer de librairie sans validation

---

## 12. Questions ouvertes pour Thrasher

À trancher avant le démarrage du Lot 1 :

1. **Les vendeurs du pilote vendent-ils des articles à variantes ?** Vêtements et chaussures rendent le Lot 1 bloquant. Électronique sans déclinaison permet d'inverser Lot 1 et Lot 2 et de démarrer le pilote plus tôt. **C'est la question qui a le plus d'impact sur le calendrier.**
2. **Suivi de stock quantitatif ou binaire ?** La quantité permet l'affichage de rareté mais impose au vendeur une tenue rigoureuse. Le binaire disponible/indisponible est plus réaliste pour démarrer.
3. **Le système d'avis existe-t-il déjà ?** Détermine si le Lot 3 est une construction ou un simple raccordement.
4. **Frais de livraison :** fixes, par zone, ou fixés par le vendeur ? Le bloc livraison en dépend.
5. **Prix par variante :** nécessaire dès le départ, ou reportable ? Le reporter simplifie beaucoup le Lot 1.
6. **Quota de stockage Supabase** disponible, pour dimensionner le passage à 8 images × 3 dérivés.

---

*Spec construite avec les skills `writing-plans` (structure et critères d'acceptation), `ui-ux-pro-max` (accessibilité, cibles tactiles, performance), `marketing-psychology` et `cro` (hiérarchie des blocs et leviers de conversion).*
