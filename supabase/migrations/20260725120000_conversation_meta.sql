-- Meta pa itilizatè sou yon konvèsasyon: epingle, favori ak etikèt kliyan.
-- Chak liy apatni a `owner_id` sèlman: se preferans PA L sou yon kontak, se
-- pa yon done pataje. Konsa de moun nan menm konvèsasyon an ka gen etikèt
-- diferan san yo pa wè sa youn lòt fè.
-- Idempotan: ka rejwe san danje.

create table if not exists public.conversation_meta (
    owner_id   uuid        not null references public.profiles(id) on delete cascade,
    contact_id uuid        not null references public.profiles(id) on delete cascade,
    pinned     boolean     not null default false,
    favorite   boolean     not null default false,
    labels     text[]      not null default '{}',
    updated_at timestamptz not null default now(),
    primary key (owner_id, contact_id),
    constraint conversation_meta_no_self check (owner_id <> contact_id),
    -- Etikèt yo se yon lis fèmen (menm valè ki nan CONV_LABELS nan index.html).
    constraint conversation_meta_labels_known check (
        labels <@ array['nouvo', 'komann', 'tann_peman', 'peye', 'fini']::text[]
    )
);

create index if not exists idx_conversation_meta_owner
    on public.conversation_meta (owner_id);

alter table public.conversation_meta enable row level security;

drop policy if exists "conversation_meta owner select" on public.conversation_meta;
create policy "conversation_meta owner select" on public.conversation_meta
    for select using (auth.uid() = owner_id);

drop policy if exists "conversation_meta owner insert" on public.conversation_meta;
create policy "conversation_meta owner insert" on public.conversation_meta
    for insert with check (auth.uid() = owner_id);

drop policy if exists "conversation_meta owner update" on public.conversation_meta;
create policy "conversation_meta owner update" on public.conversation_meta
    for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "conversation_meta owner delete" on public.conversation_meta;
create policy "conversation_meta owner delete" on public.conversation_meta
    for delete using (auth.uid() = owner_id);

grant select, insert, update, delete on public.conversation_meta to authenticated;
