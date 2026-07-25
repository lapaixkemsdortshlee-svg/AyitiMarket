-- Kat glisan nan tèt feed la (2 sous, desizyon Thrasher 2026-07-25).
--
--   announcements  — yon MESAJ (tit + kontni + dat). Li deja egziste ak
--                    `audience`, `starts_at`, `ends_at`, `active`. Nou sèlman
--                    ajoute yon imaj ak yon CTA opsyonèl pou li ka parèt kòm
--                    yon slide olye yon ti bandwòl.
--   hero_slides    — yon BANYÈ (imaj + tit kout + CTA). Se pa yon mesaj, se
--                    yon vizyèl pwomosyon. Menm chan siblaj/dat pou konpòtman
--                    efemè a rete idantik nan tou de sous yo.
--
-- Aksyon CTA a se yon KLE nan yon lis fèmen, pa yon URL ni yon bout kòd:
-- yon chan admin pa dwe janm vin yon `onclick`.
-- Idempotan: ka rejwe san danje.

alter table public.announcements add column if not exists image_url text;
alter table public.announcements add column if not exists cta_label text;
alter table public.announcements add column if not exists cta_action text;

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'announcements_cta_action_known') then
        alter table public.announcements add constraint announcements_cta_action_known
            check (cta_action is null or cta_action in ('shop', 'sell', 'orders', 'profile', 'search'));
    end if;
end $$;

create table if not exists public.hero_slides (
    id         uuid        primary key default gen_random_uuid(),
    title      text        not null,
    subtitle   text,
    badge      text,
    image_url  text,
    cta_label  text,
    cta_action text,
    audience   text        not null default 'all',
    starts_at  timestamptz,
    ends_at    timestamptz,
    active     boolean     not null default true,
    sort       integer     not null default 0,
    created_by uuid        references public.profiles(id) on delete set null,
    created_at timestamptz not null default now(),
    constraint hero_slides_title_len check (char_length(btrim(title)) between 1 and 60),
    constraint hero_slides_audience_known check (audience in ('all', 'buyers', 'sellers')),
    constraint hero_slides_cta_action_known check (
        cta_action is null or cta_action in ('shop', 'sell', 'orders', 'profile', 'search')
    ),
    constraint hero_slides_window check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index if not exists idx_hero_slides_active on public.hero_slides (active, sort);

alter table public.hero_slides enable row level security;

-- Lekti: tout moun ki konekte (slide yo se kontni piblik nan feed la).
drop policy if exists "hero_slides read" on public.hero_slides;
create policy "hero_slides read" on public.hero_slides
    for select using (true);

-- Ekriti: admin sèlman, via is_admin() ki deja la.
drop policy if exists "hero_slides admin write" on public.hero_slides;
create policy "hero_slides admin write" on public.hero_slides
    for all using (public.is_admin()) with check (public.is_admin());

grant select on public.hero_slides to anon, authenticated;
grant insert, update, delete on public.hero_slides to authenticated;
