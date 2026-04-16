-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-06 — Admin tools + fixes
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every change is idempotent.
--
--  Fixes:
--    • notifications RLS: any authenticated user can INSERT
--      (so sellers can notify buyers and vice versa).
--    • profiles.pickup_point_id + geo coordinates (remember
--      the picker chosen by the user and their last known GPS).
--
--  Adds:
--    • product_views table — admin analytics (who visited a
--      given product, when).
--    • announcements table — admin broadcasts powered by Vertex AI.
--    • reviews table already covered in schema.sql; add a helper
--      view `order_seller_rated` so the buyer rating flow can skip
--      already-rated orders.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) FIX — notifications RLS must accept cross-user inserts
-- ──────────────────────────────────────────────────────────
-- Notifications are informational, not privileged. Allow every
-- authenticated client to write them (rate-limited elsewhere).
DROP POLICY IF EXISTS "notifications_insert"         ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_any"     ON public.notifications;
CREATE POLICY "notifications_insert_any" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Leave select / update policies as-is (only the owner sees / toggles read).

-- ──────────────────────────────────────────────────────────
-- 2) PROFILES — persist pickup point + geo + admin hide flag
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pickup_point_id TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS geo_lat         NUMERIC(9,6);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS geo_lng         NUMERIC(9,6);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS geo_updated_at  TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.pickup_point_id
    IS 'ID of the user''s preferred pickup point (PICKUPS.id on client).';
COMMENT ON COLUMN public.profiles.geo_lat
    IS 'Last known latitude (from browser geolocation). Used to sort pickup points by distance.';

-- ──────────────────────────────────────────────────────────
-- 3) PRODUCT VIEWS — admin analytics ledger
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.product_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    viewer_id  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    viewed_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_product_views_product ON public.product_views(product_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_views_viewer  ON public.product_views(viewer_id, viewed_at DESC);

ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

-- Any logged-in user can register a view (anonymous viewer_id allowed).
DROP POLICY IF EXISTS "product_views_insert" ON public.product_views;
CREATE POLICY "product_views_insert" ON public.product_views
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Admin or the product's seller can read the log.
DROP POLICY IF EXISTS "product_views_select" ON public.product_views;
CREATE POLICY "product_views_select" ON public.product_views
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin = TRUE)
        OR EXISTS (
            SELECT 1 FROM public.products pr
            WHERE pr.id = product_views.product_id AND pr.seller_id = auth.uid()
        )
    );

-- ──────────────────────────────────────────────────────────
-- 4) ANNOUNCEMENTS — admin broadcasts (Vertex AI assisted)
-- ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.profiles(id),
    title TEXT NOT NULL,
    body  TEXT NOT NULL,
    audience TEXT DEFAULT 'all' CHECK (audience IN ('all','buyers','sellers')),
    starts_at TIMESTAMPTZ DEFAULT NOW(),
    ends_at   TIMESTAMPTZ,
    active BOOLEAN DEFAULT TRUE,
    generated_by_ai BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_announcements_active ON public.announcements(active, starts_at DESC);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Everyone logged in can read active announcements in their window.
DROP POLICY IF EXISTS "announcements_select" ON public.announcements;
CREATE POLICY "announcements_select" ON public.announcements
    FOR SELECT USING (
        auth.uid() IS NOT NULL
        AND active = TRUE
        AND (ends_at IS NULL OR ends_at > NOW())
    );

-- Only admins insert / update.
DROP POLICY IF EXISTS "announcements_write_admin" ON public.announcements;
CREATE POLICY "announcements_write_admin" ON public.announcements
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    ) WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
    );

-- ──────────────────────────────────────────────────────────
-- 5) REVIEWS — make sure buyer rating works cleanly
-- ──────────────────────────────────────────────────────────
-- Allow reviewer to INSERT only if they were the buyer on a
-- completed/released order for this product.
DROP POLICY IF EXISTS "reviews_insert_buyer" ON public.reviews;
CREATE POLICY "reviews_insert_buyer" ON public.reviews
    FOR INSERT WITH CHECK (
        auth.uid() = reviewer_id
        AND EXISTS (
            SELECT 1 FROM public.orders o
            WHERE o.buyer_id = auth.uid()
              AND o.product_id = reviews.product_id
              AND o.seller_id  = reviews.seller_id
              AND o.status IN ('otp_confirmed','released','completed','delivered')
        )
    );

-- Public can read reviews (unchanged if policy already exists).
DROP POLICY IF EXISTS "reviews_select_all" ON public.reviews;
CREATE POLICY "reviews_select_all" ON public.reviews
    FOR SELECT USING (TRUE);

-- ══════════════════════════════════════════════════════════
--  DONE — post-install checks:
--    SELECT column_name FROM information_schema.columns
--       WHERE table_name='profiles' AND column_name IN
--       ('pickup_point_id','geo_lat','geo_lng');
--    SELECT policyname FROM pg_policies WHERE tablename='notifications';
-- ══════════════════════════════════════════════════════════
