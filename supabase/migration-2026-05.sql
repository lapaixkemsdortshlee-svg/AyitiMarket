-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-05 — ESCROW A→Z
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every change is idempotent.
--
--  Adds:
--    • Full escrow state machine on orders (8 states)
--    • Seller MonCash payout number on profiles
--    • Admin flag + audit log (admin_actions)
--    • Singleton app_settings row (admin MonCash receive number)
--    • Helper: advance_order_status() — protects valid transitions
--  Deprecates (code-side):
--    • Wallet / recharge system (removed from UI in same release)
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) PROFILES — admin flag + seller payout number
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS moncash_number TEXT;

COMMENT ON COLUMN public.profiles.is_admin
    IS 'TRUE for platform admins who can verify payments and release escrow.';
COMMENT ON COLUMN public.profiles.moncash_number
    IS 'Seller MonCash phone (format: 509XXXXXXXX) used to receive payouts after escrow release.';

-- ──────────────────────────────────────────────────────────
-- 2) ORDERS — escrow timeline + payment proof + retry counter
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS moncash_ref          TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS net_amount           INTEGER;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS paid_at              TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS verified_at          TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS ready_at             TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivered_at         TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS released_at          TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_at         TIMESTAMPTZ;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS seller_otp_attempts  INTEGER DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS admin_note           TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS verified_by          UUID REFERENCES public.profiles(id);
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS released_by          UUID REFERENCES public.profiles(id);

COMMENT ON COLUMN public.orders.moncash_ref IS 'Transaction reference the buyer pastes in after sending MonCash transfer.';
COMMENT ON COLUMN public.orders.net_amount  IS 'Amount that will be paid out to the seller after platform fee is withheld.';

-- ──────────────────────────────────────────────────────────
-- 3) ORDERS.status — elargi pou tout etap escrow
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders
    ADD CONSTRAINT orders_status_check CHECK (status IN (
        'awaiting_payment',   -- buyer placed order, hasn't sent MonCash yet
        'payment_submitted',  -- buyer pasted MonCash ref, waiting for admin verify
        'payment_verified',   -- admin confirmed transfer → escrow active
        'ready_for_pickup',   -- seller marked product ready at pickup point
        'picked_up',           -- buyer grabbed product, OTP exchange pending
        'otp_confirmed',      -- seller entered correct OTP → delivery locked in
        'released',           -- admin released escrow to seller off-platform
        'completed',          -- final state (post-release + confirmations)
        'cancelled',          -- buyer or admin cancelled before verify
        'disputed',           -- any party flagged an issue
        'refunded',           -- admin refunded buyer
        -- Legacy values (kept so old rows don't break)
        'pending', 'confirmed', 'shipped', 'delivered'
    ));

CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_status_created ON public.orders(status, created_at DESC);

-- Map any legacy 'pending' rows to the new awaiting_payment
-- (safe because legacy pending never had a moncash_ref)
UPDATE public.orders
    SET status = 'awaiting_payment'
    WHERE status = 'pending' AND moncash_ref IS NULL;

-- ──────────────────────────────────────────────────────────
-- 4) APP SETTINGS — singleton (admin-owned MonCash number etc.)
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_settings (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    admin_moncash_number TEXT,
    fee_percent NUMERIC(5,2) DEFAULT 3.00,
    escrow_auto_release_hours INTEGER DEFAULT 168, -- 7 days
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES public.profiles(id)
);
INSERT INTO public.app_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────
-- 5) ADMIN ACTIONS — audit log for every status change admin makes
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.profiles(id),
    order_id UUID REFERENCES public.orders(id),
    action TEXT NOT NULL,                -- e.g. 'verify_payment', 'release_escrow', 'refund', 'resolve_dispute'
    from_status TEXT,
    to_status TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_actions_order ON public.admin_actions(order_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin ON public.admin_actions(admin_id, created_at DESC);

-- ──────────────────────────────────────────────────────────
-- 6) RLS — keep orders visible only to the participants + admin
--     (re-runs drop+recreate to stay idempotent)
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.orders         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_actions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings   ENABLE ROW LEVEL SECURITY;

-- Orders: buyer / seller / admin can SELECT
DROP POLICY IF EXISTS "orders_select_participants" ON public.orders;
CREATE POLICY "orders_select_participants" ON public.orders
    FOR SELECT USING (
        auth.uid() = buyer_id
        OR auth.uid() = seller_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- Orders: buyer can INSERT rows where they are the buyer
DROP POLICY IF EXISTS "orders_insert_buyer" ON public.orders;
CREATE POLICY "orders_insert_buyer" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- Orders: participants can UPDATE (app logic enforces which transitions are legal;
-- the status CHECK + advance_order_status() function guard the state machine)
DROP POLICY IF EXISTS "orders_update_participants" ON public.orders;
CREATE POLICY "orders_update_participants" ON public.orders
    FOR UPDATE USING (
        auth.uid() = buyer_id
        OR auth.uid() = seller_id
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- admin_actions: only admins can SELECT / INSERT
DROP POLICY IF EXISTS "admin_actions_admin_only" ON public.admin_actions;
CREATE POLICY "admin_actions_admin_only" ON public.admin_actions
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- app_settings: everyone logged in can SELECT (to see admin MonCash number);
-- only admins can UPDATE.
DROP POLICY IF EXISTS "app_settings_read_all" ON public.app_settings;
CREATE POLICY "app_settings_read_all" ON public.app_settings
    FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "app_settings_write_admin" ON public.app_settings;
CREATE POLICY "app_settings_write_admin" ON public.app_settings
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- ──────────────────────────────────────────────────────────
-- 7) STATE MACHINE HELPER — enforce legal transitions server-side
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.advance_order_status(
    p_order_id UUID,
    p_to_status TEXT,
    p_moncash_ref TEXT DEFAULT NULL,
    p_admin_note TEXT DEFAULT NULL
) RETURNS public.orders
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_order public.orders;
    v_actor UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_allowed BOOLEAN := FALSE;
    v_from_status TEXT;
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF v_order.id IS NULL THEN RAISE EXCEPTION 'Order not found'; END IF;
    v_from_status := v_order.status;

    SELECT is_admin INTO v_is_admin FROM public.profiles WHERE id = v_actor;

    -- Validate transition
    v_allowed := CASE
        -- Buyer actions
        WHEN v_actor = v_order.buyer_id AND v_order.status = 'awaiting_payment' AND p_to_status = 'payment_submitted' THEN TRUE
        WHEN v_actor = v_order.buyer_id AND v_order.status = 'awaiting_payment' AND p_to_status = 'cancelled' THEN TRUE
        WHEN v_actor = v_order.buyer_id AND v_order.status IN ('ready_for_pickup','otp_confirmed','released') AND p_to_status = 'disputed' THEN TRUE
        -- Seller actions
        WHEN v_actor = v_order.seller_id AND v_order.status = 'payment_verified' AND p_to_status = 'ready_for_pickup' THEN TRUE
        WHEN v_actor = v_order.seller_id AND v_order.status = 'ready_for_pickup' AND p_to_status = 'otp_confirmed' THEN TRUE
        WHEN v_actor = v_order.seller_id AND v_order.status IN ('ready_for_pickup','otp_confirmed') AND p_to_status = 'disputed' THEN TRUE
        -- Admin actions (can force any transition)
        WHEN v_is_admin = TRUE THEN TRUE
        ELSE FALSE
    END;

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Illegal transition: % → % by user %', v_order.status, p_to_status, v_actor;
    END IF;

    -- Apply side effects per target state
    UPDATE public.orders
        SET status      = p_to_status,
            moncash_ref = COALESCE(p_moncash_ref, moncash_ref),
            admin_note  = COALESCE(p_admin_note,  admin_note),
            paid_at      = CASE WHEN p_to_status = 'payment_submitted' THEN NOW() ELSE paid_at END,
            verified_at  = CASE WHEN p_to_status = 'payment_verified'  THEN NOW() ELSE verified_at END,
            verified_by  = CASE WHEN p_to_status = 'payment_verified'  THEN v_actor ELSE verified_by END,
            ready_at     = CASE WHEN p_to_status = 'ready_for_pickup'  THEN NOW() ELSE ready_at END,
            delivered_at = CASE WHEN p_to_status = 'otp_confirmed'     THEN NOW() ELSE delivered_at END,
            released_at  = CASE WHEN p_to_status = 'released'          THEN NOW() ELSE released_at END,
            released_by  = CASE WHEN p_to_status = 'released'          THEN v_actor ELSE released_by END,
            cancelled_at = CASE WHEN p_to_status IN ('cancelled','refunded') THEN NOW() ELSE cancelled_at END
        WHERE id = p_order_id
        RETURNING * INTO v_order;

    -- Audit log for admin-initiated transitions
    IF v_is_admin = TRUE THEN
        INSERT INTO public.admin_actions (admin_id, order_id, action, from_status, to_status, note)
        VALUES (v_actor, p_order_id, p_to_status, v_from_status, p_to_status, p_admin_note);
    END IF;

    RETURN v_order;
END;
$$;

GRANT EXECUTE ON FUNCTION public.advance_order_status(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────
-- 8) OTP attempt tracker — call from client when seller types OTP
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.try_seller_otp(
    p_order_id UUID,
    p_otp TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_order public.orders;
    v_actor UUID := auth.uid();
BEGIN
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF v_order.id IS NULL THEN RAISE EXCEPTION 'Order not found'; END IF;
    IF v_order.seller_id <> v_actor THEN RAISE EXCEPTION 'Not your order'; END IF;
    IF v_order.status <> 'ready_for_pickup' THEN
        RAISE EXCEPTION 'Order not ready for OTP (state %)', v_order.status;
    END IF;

    IF v_order.otp_code = p_otp THEN
        UPDATE public.orders
            SET status = 'otp_confirmed',
                delivered_at = NOW(),
                seller_otp_attempts = seller_otp_attempts + 1
            WHERE id = p_order_id;
        RETURN jsonb_build_object('ok', TRUE, 'status', 'otp_confirmed');
    ELSE
        UPDATE public.orders
            SET seller_otp_attempts = seller_otp_attempts + 1,
                status = CASE WHEN seller_otp_attempts + 1 >= 5 THEN 'disputed' ELSE status END,
                admin_note = CASE WHEN seller_otp_attempts + 1 >= 5
                                  THEN 'Auto-disputed: 5 failed OTP attempts'
                                  ELSE admin_note END
            WHERE id = p_order_id
            RETURNING * INTO v_order;
        RETURN jsonb_build_object(
            'ok', FALSE,
            'attempts', v_order.seller_otp_attempts,
            'locked', v_order.status = 'disputed'
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.try_seller_otp(UUID, TEXT) TO authenticated;

-- ══════════════════════════════════════════════════════════
--  DONE — post-install checks:
--    SELECT * FROM public.app_settings;
--    SELECT column_name FROM information_schema.columns WHERE table_name='orders';
--    SELECT id, is_admin, moncash_number FROM public.profiles LIMIT 5;
--  Then set yourself as admin:
--    UPDATE public.profiles SET is_admin = TRUE WHERE email = '<your-email>';
--  And set the MonCash receive number:
--    UPDATE public.app_settings SET admin_moncash_number = '509XXXXXXXX' WHERE id = 1;
-- ══════════════════════════════════════════════════════════
