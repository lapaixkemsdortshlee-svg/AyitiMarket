-- Banyè akèy: koulè degrade chwazi pa admin + de nouvo destinasyon CTA.
--
--   theme       — ki degrade banyè a dwe genyen. `auto` kite pozisyon an nan
--                 kawousèl la deside (konpòtman istorik la). Lòt yo fikse l,
--                 konsa admin nan wè nan apèsi a egzakteman ki koulè li pral
--                 jwenn, kèlkeswa lòd slide yo.
--   cta_action  — nou ajoute `promo` (kòd pwomo / envite yon zanmi) ak
--                 `shops` (lis boutik yo). Lis la rete FÈMEN: yon chan admin
--                 pa dwe janm vin yon `onclick` ki egzekite tèks lib.
--
-- Idempotan: ka rejwe san danje.

alter table public.hero_slides add column if not exists theme text not null default 'auto';

alter table public.hero_slides drop constraint if exists hero_slides_theme_known;
alter table public.hero_slides add constraint hero_slides_theme_known
    check (theme in ('auto', 'teal', 'deep', 'rust'));

alter table public.hero_slides drop constraint if exists hero_slides_cta_action_known;
alter table public.hero_slides add constraint hero_slides_cta_action_known
    check (cta_action is null or cta_action in ('shop', 'sell', 'orders', 'profile', 'search', 'promo', 'shops'));

alter table public.announcements drop constraint if exists announcements_cta_action_known;
alter table public.announcements add constraint announcements_cta_action_known
    check (cta_action is null or cta_action in ('shop', 'sell', 'orders', 'profile', 'search', 'promo', 'shops'));
