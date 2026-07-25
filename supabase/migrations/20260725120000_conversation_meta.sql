-- Etikèt kliyan + meta pa itilizatè sou yon konvèsasyon (epingle, favori).
--
-- De tab:
--   conversation_labels — etikèt yon vandè kreye pou tèt li (non + koulè).
--   conversation_meta   — preferans yon itilizatè sou yon kontak.
--
-- Tou de apatni a `owner_id` sèlman. Se preferans PA L: de moun nan menm
-- konvèsasyon an ka gen etikèt diferan san yo pa wè sa youn lòt fè.
-- Idempotan: ka rejwe san danje.

create table if not exists public.conversation_labels (
    id         uuid        primary key default gen_random_uuid(),
    owner_id   uuid        not null references public.profiles(id) on delete cascade,
    name       text        not null,
    color      text        not null default 'teal',
    created_at timestamptz not null default now(),
    constraint conversation_labels_name_len check (char_length(btrim(name)) between 1 and 24),
    -- Koulè yo se kle yon palèt (index.html mape yo an klè ak an sonm).
    constraint conversation_labels_color_known check (
        color in ('teal', 'rust', 'blue', 'green', 'gold', 'plum', 'slate', 'sky')
    ),
    constraint conversation_labels_uniq unique (owner_id, name)
);

create index if not exists idx_conversation_labels_owner
    on public.conversation_labels (owner_id);

alter table public.conversation_labels enable row level security;

drop policy if exists "conversation_labels owner select" on public.conversation_labels;
create policy "conversation_labels owner select" on public.conversation_labels
    for select using (auth.uid() = owner_id);

drop policy if exists "conversation_labels owner insert" on public.conversation_labels;
create policy "conversation_labels owner insert" on public.conversation_labels
    for insert with check (auth.uid() = owner_id);

drop policy if exists "conversation_labels owner update" on public.conversation_labels;
create policy "conversation_labels owner update" on public.conversation_labels
    for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "conversation_labels owner delete" on public.conversation_labels;
create policy "conversation_labels owner delete" on public.conversation_labels
    for delete using (auth.uid() = owner_id);

create table if not exists public.conversation_meta (
    owner_id   uuid        not null references public.profiles(id) on delete cascade,
    contact_id uuid        not null references public.profiles(id) on delete cascade,
    pinned     boolean     not null default false,
    favorite   boolean     not null default false,
    -- Postgres pa ka mete yon FK sou eleman yon array: se trigger anba a ki
    -- kenbe lis la pwòp lè yon etikèt efase.
    labels     uuid[]      not null default '{}',
    updated_at timestamptz not null default now(),
    primary key (owner_id, contact_id),
    constraint conversation_meta_no_self check (owner_id <> contact_id)
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

-- Lè yon etikèt efase, retire id li nan tout konvèsasyon mèt la. Fonksyon an
-- kouri ak dwa moun ki rele a (pa SECURITY DEFINER): RLS `owner_id =
-- auth.uid()` la deja otorize ekriti a, donk nou pa bezwen plis privilèj.
create or replace function public.strip_conversation_label()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    update public.conversation_meta
       set labels = array_remove(labels, old.id)
     where owner_id = old.owner_id
       and old.id = any (labels);
    return old;
end;
$$;

drop trigger if exists trg_strip_conversation_label on public.conversation_labels;
create trigger trg_strip_conversation_label
    after delete on public.conversation_labels
    for each row execute function public.strip_conversation_label();

grant select, insert, update, delete on public.conversation_labels to authenticated;
grant select, insert, update, delete on public.conversation_meta   to authenticated;
