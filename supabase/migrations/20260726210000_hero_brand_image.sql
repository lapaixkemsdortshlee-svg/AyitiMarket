-- Imaj kat « Dekouvri Ekomat » nan tèt feed la (desizyon Thrasher 2026-07-26).
--
-- Kat mak la se PA yon liy nan `hero_slides`: tit li, sou-tit li ak bouton li
-- chanje otomatikman selon si moun nan se yon achtè oswa yon vandè, epi
-- pastiy li di bonjou ak non moun nan. Se sèlman IMAJ li ki fiks, kidonk li
-- ale nan `app_settings` (yon sèl liy, id = 1, ekriti admin sèlman) kòm yon
-- paramèt aplikasyon an, olye pou l ta vin yon katriyèm sous nan kawousèl la.
--
-- Politik RLS yo deja la sou `app_settings`:
--   lekti  — nenpòt moun ki KONEKTE  (auth.uid() is not null)
--   ekriti — admin sèlman (`profiles.is_admin`)
-- Ekriti a pa bezwen anyen nouvo: se admin ki chwazi imaj la.
--
-- Men LEKTI a se yon pwoblèm: `enterGuestMode` pa louvri okenn sesyon
-- Supabase, kidonk pou yon vizitè ki pa konekte `auth.uid()` nil epi rekèt la
-- pa retounen okenn liy. Kat « Dekouvri Ekomat » se PREMYE bagay yon vizitè
-- wè, li ta rete san imaj pou egzakteman moun nou vle konvenk yo.
--
-- Nou PA louvri tab la pou `anon`: li gen `admin_moncash_number` ladan l. Nou
-- ekspoze yon SÈL kolòn, via yon fonksyon `security definer` ki pa li anyen
-- lòt. URL la se yon lyen piblik nan bucket `Avatar` la, li pa sansib.
--
-- Idempotan: ka rejwe san danje.

alter table public.app_settings add column if not exists hero_brand_image_url text;

comment on column public.app_settings.hero_brand_image_url is
    'URL piblik imaj kat mak la nan tèt feed la (bucket Avatar). NULL = ikòn boutik la.';

create or replace function public.hero_brand_image()
returns text
language sql
stable
security definer
set search_path = public
as $$
    select hero_brand_image_url from public.app_settings where id = 1;
$$;

comment on function public.hero_brand_image() is
    'Imaj kat mak la sèlman, lizib pou vizitè ki pa konekte. Pa ekspoze okenn lòt kolòn nan app_settings.';

-- `security definer` dwe toujou gen yon lis egzekisyon eksplisit: nou retire
-- default `public` la anvan nou bay dwa a.
revoke all on function public.hero_brand_image() from public;
grant execute on function public.hero_brand_image() to anon, authenticated;
