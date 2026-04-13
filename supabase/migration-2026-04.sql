-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-04
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every change is idempotent.
-- ══════════════════════════════════════════════════════════

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
-- 3) NOTIFICATIONS — ensure the 4 event types & performant reads
--     type ∈ ('order','system','chat','promo')  — already enforced
--     (order = new order, chat = new message, system = new follower
--      OR system alert, promo = promotions)
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

-- ──────────────────────────────────────────────────────────
-- 5) OPTIONAL: Auto-notify seller on new order
--    Guarantees a notifications row even if the client forgets.
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_seller_on_order()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, type, icon, title, body, color)
    VALUES (
        NEW.seller_id,
        'order',
        'shopping_bag',
        'Nouvo komand!',
        COALESCE(NEW.buyer_name, 'Yon kliyan') || ' komande ' ||
            COALESCE(NEW.product_title, 'yon pwodwi') || '.',
        '#00666f'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_seller_on_order ON public.orders;
CREATE TRIGGER trg_notify_seller_on_order
    AFTER INSERT ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.notify_seller_on_order();

-- ──────────────────────────────────────────────────────────
-- 6) OPTIONAL: Auto-notify seller on new follower
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_seller_on_follow()
RETURNS TRIGGER AS $$
DECLARE
    follower_name TEXT;
BEGIN
    SELECT display_name INTO follower_name
        FROM public.profiles WHERE id = NEW.follower_id;

    INSERT INTO public.notifications (user_id, type, icon, title, body, color)
    VALUES (
        NEW.seller_id,
        'system',
        'person_add',
        'Nouvo abonnen!',
        COALESCE(follower_name, 'Yon moun') || ' kounye a swiv boutik ou.',
        '#00666f'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_seller_on_follow ON public.followers;
CREATE TRIGGER trg_notify_seller_on_follow
    AFTER INSERT ON public.followers
    FOR EACH ROW EXECUTE FUNCTION public.notify_seller_on_follow();

-- ──────────────────────────────────────────────────────────
-- 7) OPTIONAL: Auto-notify receiver on new chat message
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_on_new_message()
RETURNS TRIGGER AS $$
DECLARE
    sender_name TEXT;
    preview TEXT;
BEGIN
    -- Never notify yourself, never duplicate on "self-dm"
    IF NEW.sender_id = NEW.receiver_id THEN
        RETURN NEW;
    END IF;

    SELECT display_name INTO sender_name
        FROM public.profiles WHERE id = NEW.sender_id;

    -- Preview content, masking location payloads
    preview := CASE
        WHEN LEFT(NEW.content, 5) = '[LOC]' THEN '📍 Lokalisasyon pataje'
        ELSE LEFT(NEW.content, 80)
    END;

    INSERT INTO public.notifications (user_id, type, icon, title, body, color)
    VALUES (
        NEW.receiver_id,
        'chat',
        'chat',
        'Nouvo mesaj',
        COALESCE(sender_name, 'Yon kliyan') || ': ' || preview,
        '#00666f'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_on_new_message ON public.messages;
CREATE TRIGGER trg_notify_on_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_message();

-- ══════════════════════════════════════════════════════════
--  DONE — verify with:
--     SELECT column_name, data_type FROM information_schema.columns
--         WHERE table_name = 'profiles';
--     SELECT * FROM public.notifications ORDER BY created_at DESC LIMIT 5;
-- ══════════════════════════════════════════════════════════
