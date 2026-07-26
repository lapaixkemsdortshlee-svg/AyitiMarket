# Ekomat (ex-AyitiMarket) : Palèt mak / Brand palette

Source de vérité des couleurs : `index.html` (tokens Tailwind inline, lignes 56-73 ; dark mode `--dm-*`, lignes 771-786 ; logo/drapeau, lignes 1341-1345 & 1408). Ce fichier documente les codes ; il ne remplace pas la config.

Version visuelle (swatches cliquables, copie au clic) :
- Palette complète : https://claude.ai/code/artifact/f7ea72df-58bf-4144-8993-6c49c60ebc24
- Kit logo (4 couleurs) : voir l'artifact « Kit logo »

---

## 1. Mak prensipal la, les 4 couleurs signature

Pour toute brand identity (logo, kat vizit, social, print), **utilise seulement ces 4**.

| Koulè | Rôle | HEX | RGB | HSL | Tailwind |
|---|---|---|---|---|---|
| **Teal** | Prensipal, bouton, CTA, lyen, « mat » + anse logo a | `#00666F` | `rgb(0, 102, 111)` | `hsl(185, 100%, 22%)` | `primary` |
| **Brick** | Segondè, badge panye/mesaj | `#98443E` | `rgb(152, 68, 62)` | `hsl(4, 42%, 42%)` | `secondary` |
| **Rust** | Aksan : « eko » + boul « e » logo a, admin, ti detay | `#97422B` | `rgb(151, 66, 43)` | `hsl(13, 56%, 38%)` | `tertiary` |
| **Cream** | Sifas, fon aplikasyon an | `#FCF9F4` | `rgb(252, 249, 244)` | `hsl(37, 57%, 97%)` | `surface` |

Règ (rebrand Ekomat 2026-07-11) : **eko** toujou rust `#97422B`, **mat** toujou teal `#00666F`. Sou fon fonse, « mat » vin `#5AD7E6`.

## 2. Degrade signati

| Non | CSS |
|---|---|
| CTA / bouton prensipal | `linear-gradient(180deg, #00666f, #00818c)` |
| Hero / header | `linear-gradient(160deg, #00666f, #00818c)` |
| Rust / admin | `linear-gradient(135deg, #97422b, #b65a41)` |
| Medayon boutik | `linear-gradient(155deg, #00939e, #00666f)` |
| AI / try-on | `linear-gradient(135deg, #7c3aed, #4f46e5)` |

## 3. Teal & kontenè

| Non | HEX | Tailwind |
|---|---|---|
| Primary Container | `#00818C` | `primary-container` |
| Primary Fixed | `#8CF2FF` | `primary-fixed` |
| Fixed Dim / Accent | `#5AD7E6` | `primary-fixed-dim` |
| On Primary Fixed | `#001F23` | `on-primary-fixed` |
| Salmon | `#F99188` | `secondary-container` |
| Rust Clair | `#B65A41` | `tertiary-container` |

## 4. Sifas & nòt (mòd klè)

| Non | HEX | Tailwind |
|---|---|---|
| White | `#FFFFFF` | `surface-container-lowest` |
| Surface | `#FCF9F4` | `surface` |
| Container Low | `#F6F3EE` | `surface-container-low` |
| Container | `#F0EDE8` | `surface-container` |
| Container High | `#EBE8E3` | `surface-container-high` |
| Container Highest | `#E5E2DD` | `surface-container-highest` |
| Ink / Text | `#1C1C19` | `on-surface` |
| Muted Text | `#3D4949` | `on-surface-variant` |
| Outline | `#BCC9C8` | `outline-variant` |

## 5. Mòd fonse (dark)

| Non | HEX | Var CSS |
|---|---|---|
| BG | `#1C1C19` | `--dm-bg` |
| Surface | `#252521` | `--dm-surface` |
| Card | `#2E2E2A` | `--dm-card` |
| High | `#383834` | `--dm-high` |
| Highest | `#404040` | `--dm-highest` |
| Text | `#FCF9F4` | `--dm-text` |
| Sub | `#A8B0B0` | `--dm-sub` |
| Accent | `#5AD7E6` | `--dm-accent` |
| Red | `#F99188` | `--dm-red` |
| Border | `rgba(255,255,255,.06)` | `--dm-border` |

## 6. Koulè semantik (fonksyonèl, pa mak)

- **Success** : `#065F46` · `#059669` · `#22C55E`
- **Error** : `#991B1B` · `#DC2626` · `#F99188`
- **Warning** : `#92400E` · `#D97706` · `#F59E0B`
- **Info** : `#1E40AF` · `#1976D2`
- **AI / purple** : `#7C3AED` · `#4F46E5`

## 7. Logo & drapo Ayiti (mis à jour Ekomat)

| Non | HEX | RGB | HSL |
|---|---|---|---|
| eko + boul « e » (rust) | `#97422B` | `rgb(151, 66, 43)` | `hsl(13, 56%, 38%)` |
| mat + anse (teal) | `#00666F` | `rgb(0, 102, 111)` | `hsl(185, 100%, 22%)` |
| mat dark | `#5AD7E6` | `rgb(90, 215, 230)` | `hsl(186, 74%, 63%)` |
| Flag Blue | `#00209F` | `rgb(0, 32, 159)` | `hsl(228, 100%, 31%)` |
| Flag Red | `#D21034` | `rgb(210, 16, 52)` | `hsl(349, 86%, 44%)` |
| Flag Green | `#006B3F` | `rgb(0, 107, 63)` | `hsl(155, 100%, 21%)` |
