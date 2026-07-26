-- Imaj kat « Dekouvri Ekomat » nan tèt feed la (desizyon Thrasher 2026-07-26).
--
-- Kat mak la se PA yon liy nan `hero_slides`: tit li, sou-tit li ak bouton li
-- chanje otomatikman selon si moun nan se yon achtè oswa yon vandè, epi
-- pastiy li di bonjou ak non moun nan. Se sèlman IMAJ li ki fiks, kidonk li
-- ale nan `app_settings` (yon sèl liy, id = 1, ekriti admin sèlman) kòm yon
-- paramèt aplikasyon an, olye pou l ta vin yon katriyèm sous nan kawousèl la.
--
-- Politik RLS yo deja la sou `app_settings`:
--   lekti  — nenpòt moun ki konekte
--   ekriti — admin sèlman (`profiles.is_admin`)
-- Kidonk pa gen okenn nouvo politik pou ekri isit la.
--
-- Idempotan: ka rejwe san danje.

alter table public.app_settings add column if not exists hero_brand_image_url text;

comment on column public.app_settings.hero_brand_image_url is
    'URL piblik imaj kat mak la nan tèt feed la (bucket Avatar). NULL = ikòn boutik la.';
