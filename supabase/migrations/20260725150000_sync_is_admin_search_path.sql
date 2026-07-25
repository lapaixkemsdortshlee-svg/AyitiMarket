-- Fikse search_path la sou trigger ki senkronize profiles.is_admin ak
-- profiles.role la (PR #236). Advisor Supabase la siyale l:
-- `function_search_path_mutable`.
--
-- Poukisa sa enpòtan: san yon search_path fiks, se search_path moun ki rele
-- a ki aplike. Yon moun ki ta ka kreye yon sqema devan `public` nan chemen
-- an ta ka fè fonksyon an vize lòt objè. Fonksyon an tache ak yon trigger
-- sou `profiles`, ki se otorite admin la: nou pa kite l flannen.
--
-- Kò a rete IDANTIK ak sa ki sou pwodiksyon an; sèl `set search_path` la
-- ajoute. Fonksyon an rete SECURITY INVOKER (li pa t janm DEFINER).
-- Idempotan: `create or replace`, trigger la pa touche.

create or replace function public.sync_is_admin_with_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    new.is_admin := ((new.role = 'admin') is true);   -- janm null
    return new;
end;
$$;
