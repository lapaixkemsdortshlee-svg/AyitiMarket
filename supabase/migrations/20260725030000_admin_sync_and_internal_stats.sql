-- 1) YON SÈL SOUS VERITE POU ADMIN
-- Gen DE nosyon admin nan baz la: profiles.role='admin' (sa app la ak
-- fonksyon is_admin() sèvi) EPI ansyen kolòn profiles.is_admin (sa RPC
-- kritik yo sèvi: advance_order_status, funnel_overview, error_overview...).
-- Yo te ka divèje: nouvo admin lan te gen role='admin' men is_admin=false
-- (li PA t ka lage eskwo), epi ansyen kont ki rétrograde a te kenbe
-- is_admin=true (li t ap toujou gen pouvwa RPC). Trigger sa a fè kolòn nan
-- toujou swiv wòl la, konsa yo pa ka janm divèje ankò.

create or replace function public.sync_is_admin_with_role()
returns trigger
language plpgsql
as $$
begin
    new.is_admin := ((new.role = 'admin') is true);   -- janm null
    return new;
end;
$$;

drop trigger if exists trg_sync_is_admin on public.profiles;
create trigger trg_sync_is_admin
    before insert or update of role on public.profiles
    for each row execute function public.sync_is_admin_with_role();

-- Rekonsilye done ki deja la (idempotan).
update public.profiles
set is_admin = ((role = 'admin') is true)
where is_admin is distinct from ((role = 'admin') is true);

-- 2) KONT ENTÈN PA DWE FOSE ESTATISTIK YO
-- Kont Thrasher yo (admin, boutik ofisyèl, kont tès) te konte tankou vrè
-- itilizatè nan funnel_overview -> chif yo pa t reyèl.
alter table public.profiles
    add column if not exists internal_account boolean not null default false;

comment on column public.profiles.internal_account is
    'true = kont entèn (ekip/tès). Eskli nan funnel_overview pou estatistik yo rete vre.';

-- 3) funnel_overview: eskli kont entèn yo (ak kòmand yo) + tcheke wòl la
create or replace function public.funnel_overview()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
DECLARE
    v_result JSONB;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.profiles
                   WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'funnel_overview: admin only';
    END IF;

    WITH real_users AS (
        SELECT * FROM public.profiles WHERE internal_account IS NOT TRUE
    ),
    real_orders AS (
        SELECT o.* FROM public.orders o
        WHERE o.buyer_id IN (SELECT id FROM real_users)
    ),
    buyer_orders AS (
        SELECT buyer_id,
               COUNT(*) AS n_orders,
               COUNT(*) FILTER (WHERE status IN ('otp_confirmed','released','completed')) AS n_fulfilled
        FROM real_orders
        WHERE buyer_id IS NOT NULL
        GROUP BY buyer_id
    ),
    agg AS (
        SELECT
            (SELECT COUNT(*) FROM real_users)                                               AS users_total,
            (SELECT COUNT(*) FROM real_users WHERE created_at >= now() - interval '7 days')  AS users_7d,
            (SELECT COUNT(*) FROM real_users WHERE created_at >= now() - interval '30 days') AS users_30d,
            (SELECT COUNT(*) FROM real_users WHERE referred_by IS NOT NULL)                 AS users_referred,
            (SELECT COUNT(*) FROM buyer_orders)                                             AS buyers,
            (SELECT COUNT(*) FROM buyer_orders WHERE n_fulfilled >= 1)                      AS activated,
            (SELECT COUNT(*) FROM buyer_orders WHERE n_orders >= 2)                         AS repeat_buyers,
            (SELECT COUNT(*) FROM public.promo_codes WHERE scope = 'referral_reward')       AS rewards_granted,
            (SELECT COALESCE(SUM(total_amount) FILTER (WHERE status IN ('released','completed')), 0) FROM real_orders) AS gmv,
            (SELECT COALESCE(SUM(COALESCE(net_amount, total_amount - COALESCE(fee_amount,0)))
                    FILTER (WHERE status IN ('released','completed')), 0) FROM real_orders) AS net_sellers,
            (SELECT COALESCE(SUM(COALESCE(fee_amount,0)) FILTER (WHERE status IN ('released','completed')), 0) FROM real_orders) AS fees,
            (SELECT COUNT(*) FILTER (WHERE status IN ('released','completed')) FROM real_orders) AS paid_orders
    )
    SELECT jsonb_build_object(
        'generated_at', now(),
        'acquisition', jsonb_build_object(
            'total_users',       users_total,
            'new_7d',            users_7d,
            'new_30d',           users_30d,
            'referral_acquired', users_referred
        ),
        'activation', jsonb_build_object(
            'buyers',              buyers,
            'activated',           activated,
            'signup_to_buyer_pct', CASE WHEN users_total > 0
                                        THEN round(100.0 * buyers / users_total, 1) ELSE 0 END
        ),
        'retention', jsonb_build_object(
            'repeat_buyers', repeat_buyers,
            'repeat_pct',    CASE WHEN buyers > 0
                                  THEN round(100.0 * repeat_buyers / buyers, 1) ELSE 0 END
        ),
        'referral', jsonb_build_object(
            'referred_signups', users_referred,
            'rewards_granted',  rewards_granted
        ),
        'revenue', jsonb_build_object(
            'gmv_htg',            gmv,
            'net_to_sellers_htg', net_sellers,
            'fees_htg',           fees,
            'paid_orders',        paid_orders,
            'aov_htg',            CASE WHEN paid_orders > 0 THEN round(gmv / paid_orders) ELSE 0 END
        )
    )
    INTO v_result
    FROM agg;

    RETURN v_result;
END;
$function$;
