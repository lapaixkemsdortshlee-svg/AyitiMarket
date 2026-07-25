-- Boutik Ofisyèl Ekomat: yon vandè premye-pati ki make an lò, diferan de
-- badj "Verifye" teal la. Se PA yon nivo pi wo pou vandè — se yon eta
-- (boutik plateform lan menm), konsa okenn vandè pa ka santi l enjis.
-- Idempotan, pa destriktif (kolòn boolean ak defo false).

alter table public.profiles
    add column if not exists official_seller boolean not null default false;

comment on column public.profiles.official_seller is
    'true = Boutik Ofisyèl Ekomat (premye-pati). Montre yon badj lò olye badj Verifye a.';
