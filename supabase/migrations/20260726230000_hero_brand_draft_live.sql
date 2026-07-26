-- Kat « Dekouvri Ekomat »: tout chan yo vin modifyab, ak yon eta BOUYON
-- separe de eta DEPLWAYE a (demann Thrasher 2026-07-26).
--
-- Anvan, sèl bagay admin te ka chanje se te imaj la, epi chanjman an te rive
-- devan itilizatè yo lamenm. Kounye a:
--   hero_brand_draft : sa admin ap travay sou li. PÈSONN pa wè l.
--   hero_brand_live  : sa itilizatè yo wè. Li chanje SÈLMAN lè admin konfime.
--
-- Fòm jsonb la: { badge, title, subtitle, theme, cta_label, cta_action,
-- image_url }. Chak chan opsyonèl: `null` vle di « kite valè otomatik la »,
-- konsa kat la kontinye di bonjou ak non moun nan epi adapte tèks li selon
-- wòl la toutotan admin pa ranplase chan an.
--
-- Yon jsonb epi pa sèt kolòn: chan sa yo se yon sèl objè ki dwe deplwaye
-- ansanm, epi yo pa janm rechèche endividyèlman.
--
-- Idempotan: ka rejwe san danje.

alter table public.app_settings add column if not exists hero_brand_draft jsonb;
alter table public.app_settings add column if not exists hero_brand_live  jsonb;

comment on column public.app_settings.hero_brand_draft is
    'Bouyon kat mak la, vizib sèlman pou admin nan fèy Banyè Akèy la.';
comment on column public.app_settings.hero_brand_live is
    'Eta deplwaye kat mak la. Se sèl sa itilizatè yo wè.';

-- Imaj ki deja deplwaye a pa dwe pèdi: nou pote l nan de eta yo.
update public.app_settings
   set hero_brand_live  = coalesce(hero_brand_live,  jsonb_build_object('image_url', hero_brand_image_url)),
       hero_brand_draft = coalesce(hero_brand_draft, jsonb_build_object('image_url', hero_brand_image_url))
 where id = 1 and hero_brand_image_url is not null;

-- Lekti piblik: SÈLMAN eta deplwaye a. Yon vizitè ki pa konekte dwe ka wè kat
-- la (`enterGuestMode` pa louvri okenn sesyon), men `app_settings` gen
-- `admin_moncash_number` ladan l, kidonk nou pa louvri tab la.
create or replace function public.hero_brand()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(hero_brand_live, '{}'::jsonb) from public.app_settings where id = 1;
$$;

comment on function public.hero_brand() is
    'Eta DEPLWAYE kat mak la sèlman. Pa janm ekspoze bouyon an ni lòt kolòn app_settings.';

revoke all on function public.hero_brand() from public;
grant execute on function public.hero_brand() to anon, authenticated;

-- Ansyen fonksyon an rete pou yon kliyan ki poko rafrechi (service worker):
-- li li eta deplwaye a kounye a, ak repli sou ansyen kolòn nan.
create or replace function public.hero_brand_image()
returns text
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(hero_brand_live->>'image_url', hero_brand_image_url)
      from public.app_settings where id = 1;
$$;

revoke all on function public.hero_brand_image() from public;
grant execute on function public.hero_brand_image() to anon, authenticated;
