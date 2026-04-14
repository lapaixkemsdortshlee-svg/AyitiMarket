-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-04
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every change is idempotent.
--  Schema additions only — client handles notification creation.
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 0) CLEANUP — remove any notification triggers from earlier
--    migration drafts so client-side inserts aren't duplicated.
-- ──────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_notify_seller_on_order   ON public.orders;
DROP TRIGGER IF EXISTS trg_notify_seller_on_follow  ON public.followers;
DROP TRIGGER IF EXISTS trg_notify_on_new_message    ON public.messages;
DROP FUNCTION IF EXISTS public.notify_seller_on_order();
DROP FUNCTION IF EXISTS public.notify_seller_on_follow();
DROP FUNCTION IF EXISTS public.notify_on_new_message();

-- ──────────────────────────────────────────────────────────
-- 1) PROFILES — add `categories` (seller's selling categories)
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS categories TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.profiles.categories
    IS 'Categories a seller is authorized / plans to sell in (e.g. mode, electronique, gaming, beaute).';

-- ──────────────────────────────────────────────────────────
-- 2) PRODUCTS — extend the allowed category list
--     (mode, cosmetique, accessoire, artisanat, maison, bebe,
--      electronique, gaming, beaute)
-- ──────────────────────────────────────────────────────────
ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_category_check;

ALTER TABLE public.products
    ADD CONSTRAINT products_category_check
    CHECK (category IN (
        'mode', 'cosmetique', 'accessoire', 'artisanat', 'maison', 'bebe',
        'electronique', 'gaming', 'beaute'
    ));

-- Index reminder (no-op if it already exists)
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_status_created ON public.products(status, created_at DESC);

-- ──────────────────────────────────────────────────────────
-- 3) NOTIFICATIONS — performant reads for red-dot + inbox
--     type ∈ ('order','system','chat','promo')  — already enforced
-- ──────────────────────────────────────────────────────────

-- Composite index: "unread by user, newest first" — powers the red dot
CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
    ON public.notifications(user_id, read, created_at DESC);

-- Lookup index: list a user's notifications newest first
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications(user_id, created_at DESC);

-- ──────────────────────────────────────────────────────────
-- 4) MESSAGES — helper indexes for the inbox + unread counter
-- ──────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_messages_receiver_read
    ON public.messages(receiver_id, read);

CREATE INDEX IF NOT EXISTS idx_messages_sender_receiver_created
    ON public.messages(sender_id, receiver_id, created_at DESC);

-- ══════════════════════════════════════════════════════════
--  DONE — verify with:
--     SELECT column_name, data_type FROM information_schema.columns
--         WHERE table_name = 'profiles';
--     SELECT * FROM public.notifications ORDER BY created_at DESC LIMIT 5;
-- ══════════════════════════════════════════════════════════
