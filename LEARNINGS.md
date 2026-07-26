# LEARNINGS

Mémoire des corrections reçues sur ce projet. Lu avant chaque action, alimenté après chaque correction.

Dernière consolidation : (jamais)

---

## Règles permanentes

Leçons arrivées à 3 occurrences ou plus. Lues systématiquement, elles priment sur tout le reste.

- Jamais de tiret cadratin, quel que soit le support.
- Une preuve répond à la question qu'elle pose, jamais à celle d'à côté. « Je ne l'ai pas introduit » et « ce n'est pas réel » sont deux affirmations distinctes, et la première ne soutient jamais la seconde. Avant de qualifier un signalement de faux positif, aller lire le signalement lui-même.
- Sur un gros diff touchant `index.html`, CodeQL réétiquette ses alertes baseline en « new alerts » (PR #99, #151, #152, #246 ; son résumé dit « code changes were too large »). Ce label est trompeur, le contenu ne l'est pas. Deux vérifications distinctes et obligatoires : (1) est-ce que je l'ai introduit ? rejouer la transformation sur la version précédente et differ, les lignes restantes doivent être exactement les changements voulus ; (2) est-ce réel ? ouvrir les annotations et juger chaque règle sur le code visé. Sur #246 la réponse était non à la première et OUI à la seconde, dix sites échappaient l'apostrophe sans l'antislash.

---

## Entrées actives

Les plus récentes en premier.

### 2026-07-26 | process | Théoriser sur le rendu sans lire les données saisies
- **Erreur** : sur « le retour à la ligne n'est pas respecté » dans les bannières, j'ai théorisé une cause sophistiquée avant de rien mesurer : `text-wrap: balance` combiné à la différence de largeur entre la feuille admin (padding 24px) et le feed (`px-4`) déplacerait la coupe. Reproduction sur le vrai `index.html` servi en HTTP, à 320, 360, 390, 414, 430 et 520px : faux, la coupe était déjà identique partout, avant comme après. La vraie cause était triviale, les champs étaient des `<input>`, qui ne peuvent contenir aucun retour à la ligne. Thrasher n'avait aucun moyen d'en écrire un.
- **Correction** : la réponse était dans ses données, pas dans le CSS. Le sous-titre en base valait `"Nan retrè a ,ou bay kod 6 chif ou a .Se lè sa vandè a peye."`, avec un espace AVANT la ponctuation et aucun après. C'est la trace visible d'une tentative de forcer une coupe à la main. Passage en `<textarea>` plus `white-space: pre-line`.
- **Règle** : avant de théoriser sur un défaut de rendu, lire les données réelles que l'utilisateur a saisies. Elles portent souvent la trace de ce qu'il essayait d'obtenir, et cette trace nomme le manque mieux que n'importe quelle hypothèse sur la cascade. Corollaire de méthode : mesurer une coupe de ligne caractère par caractère avec `Range.getClientRects` plutôt que de juger à l'œil sur une capture.
- **Occurrences** : 1

### 2026-07-26 | ui | Le mauvais paramètre, trois fois de suite
- **Erreur** : la découpe sous la carte du feed a été refusée trois fois. À chaque refus j'ai retouché la courbure (points de contrôle du Bézier, hauteur, largeur du viewBox) alors que le vrai défaut était ailleurs : le SVG faisait toute la largeur de la carte et posait une bande de 7 px sur l'intégralité du bord bas, ce qui écrasait les coins arrondis. Ce n'était pas la courbe qui clochait, c'était son emprise.
- **Correction** : une seule colline en largeur fixe, centrée, dont la base coïncide avec le bord bas et dont les deux bouts s'éteignent à zéro. Les coins restent intacts, et les tangentes horizontales aux raccords suppriment les accroches par construction, pas par retouche.
- **Règle** : quand trois réglages successifs d'un même paramètre échouent, ce n'est plus le réglage qui est faux, c'est le paramètre. Redécrire le problème avant de retoucher une quatrième valeur.
- **Occurrences** : 1

### 2026-07-25 | ui | Correctif sur la mauvaise couche
- **Erreur** : le spinner de recherche d'adresse tournait sans fin. J'ai réécrit sa logique JS (compteur, `finally`, abort), livré, et il tournait toujours.
- **Correction** : la cause était dans la cascade CSS, pas dans le JS. `.hidden` vient de `assets/tw.css` chargé avant le bloc `<style>` inline ; à spécificité égale `.material-symbols-outlined` gagnait et annulait `display:none`.
- **Règle** : quand un correctif ne change rien au symptôme, changer de couche au lieu de retoucher la même. Vérifier le style calculé dans le navigateur avant de réécrire de la logique.
- **Occurrences** : 1

### 2026-07-25 | ui | Locale non supportée en Kreyòl
- **Erreur** : `toLocaleDateString('ht', …)` affichait « April 2026 » dans une app entièrement en Kreyòl.
- **Correction** : la locale `ht` n'est pas supportée par Intl, le navigateur retombe sur l'anglais. Formater les dates avec une table de mois Kreyòl explicite.
- **Règle** : ne jamais confier un texte visible en Kreyòl à `toLocaleDateString`, la locale n'existe pas.
- **Occurrences** : 1

### 2026-07-25 | process | Contrainte déclarée sans mesure
- **Erreur** : j'ai annoncé qu'il était impossible de remonter le titre de Mesaj yo, en supposant que `#topbar` recevait un `safe-area-inset-top` qui le rendait plus haut sur iPhone.
- **Correction** : Thrasher a demandé de vérifier. Le `safe-area-inset-top` ne s'applique qu'aux feuilles plein écran. La barre fait 64 px sur tous les appareils, le titre est monté de 8 px sans risque.
- **Règle** : ne jamais annoncer une contrainte bloquante sans l'avoir mesurée dans le code ou dans le navigateur.
- **Occurrences** : 1

---

## Archive

Entrées à occurrence unique, sans récidive depuis plus de 90 jours. Conservées au cas où elles réapparaissent.

(vide)
