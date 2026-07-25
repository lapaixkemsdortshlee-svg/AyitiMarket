# LEARNINGS

Mémoire des corrections reçues sur ce projet. Lu avant chaque action, alimenté après chaque correction.

Dernière consolidation : (jamais)

---

## Règles permanentes

Leçons arrivées à 3 occurrences ou plus. Lues systématiquement, elles priment sur tout le reste.

- Jamais de tiret cadratin, quel que soit le support.

---

## Entrées actives

Les plus récentes en premier.

### 2026-07-25 | process | Contrainte déclarée sans mesure
- **Erreur** : j'ai annoncé qu'il était impossible de remonter le titre de Mesaj yo, en supposant que `#topbar` recevait un `safe-area-inset-top` qui le rendait plus haut sur iPhone.
- **Correction** : Thrasher a demandé de vérifier. Le `safe-area-inset-top` ne s'applique qu'aux feuilles plein écran. La barre fait 64 px sur tous les appareils, le titre est monté de 8 px sans risque.
- **Règle** : ne jamais annoncer une contrainte bloquante sans l'avoir mesurée dans le code ou dans le navigateur.
- **Occurrences** : 1

---

## Archive

Entrées à occurrence unique, sans récidive depuis plus de 90 jours. Conservées au cas où elles réapparaissent.

(vide)
