-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Supabase Database Schema
--  Execute this in: Supabase Dashboard > SQL Editor > New Query
-- ══════════════════════════════════════════════════════════

-- ── 1. PROFILES (extends Supabase auth.users) ──
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    display_name TEXT,
    email TEXT,
    phone TEXT,
    role TEXT DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
    avatar_url TEXT,
    verified_seller BOOLEAN DEFAULT FALSE,
    rating_avg NUMERIC(3,2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    sales_count INTEGER DEFAULT 0,
    order_count INTEGER DEFAULT 0,
    location TEXT,
    bio TEXT,
    -- Stamp the moment the seller last changed their display_name.
    -- Bug J: a seller can only rename their shop once every 30 days;
    -- the UI checks this column and re-stamps it on a successful rename.
    shop_name_changed_at TIMESTAMPTZ,
    specialties TEXT[] DEFAULT '{}',
    response_time TEXT,
    badges TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'pending', 'banned')),
    -- Bug Block-User: companion fields for status='banned'.
    --   banned_until = NULL  → permanent ban (definitive)
    --   banned_until in fute → temporary ban; auto-promotes back to
    --                           'active' on next login after expiry.
    -- ban_reason is shown to the user via the in-app notification.
    banned_until TIMESTAMPTZ,
    ban_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, first_name, last_name, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            CONCAT(
                COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
                ' ',
                COALESCE(NEW.raw_user_meta_data->>'last_name', '')
            )
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 2. PRODUCTS ──
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    price INTEGER NOT NULL CHECK (price > 0),
    old_price INTEGER,
    category TEXT NOT NULL CHECK (category IN ('mode', 'beaute', 'cosmetique', 'electronique', 'gaming', 'accessoire', 'artisanat', 'maison', 'bebe')),
    location TEXT,
    stock INTEGER DEFAULT 1 CHECK (stock >= 0),
    views INTEGER DEFAULT 0,
    sizes TEXT[] DEFAULT '{}',
    images TEXT[] DEFAULT '{}',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'draft', 'sold', 'archived')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_seller ON public.products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);

-- ── 3. ORDERS ──
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID REFERENCES public.profiles(id),
    seller_id UUID REFERENCES public.profiles(id),
    product_id UUID REFERENCES public.products(id),
    product_title TEXT,
    buyer_name TEXT,
    seller_name TEXT,
    quantity INTEGER DEFAULT 1,
    unit_price INTEGER NOT NULL,
    total_amount INTEGER NOT NULL,
    fee_amount INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'disputed')),
    payment_method TEXT DEFAULT 'MonCash',
    pickup_location TEXT,
    otp_code TEXT,
    escrow_released BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_buyer ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller ON public.orders(seller_id);

-- ── 4. CART ITEMS ──
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    qty INTEGER DEFAULT 1 CHECK (qty > 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- ── 5. MESSAGES (Chat) ──
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_product ON public.messages(product_id);

-- ── 6. FAVORITES ──
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- ── 7. FOLLOWERS ──
CREATE TABLE IF NOT EXISTS public.followers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    seller_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(follower_id, seller_id)
);

-- ── 8. NOTIFICATIONS ──
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'system' CHECK (type IN ('order', 'system', 'chat', 'promo')),
    icon TEXT DEFAULT 'notifications',
    title TEXT NOT NULL,
    body TEXT,
    color TEXT DEFAULT '#00666f',
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);

-- ── 9. FLASH DEALS ──
CREATE TABLE IF NOT EXISTS public.flash_deals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    price INTEGER NOT NULL,
    old_price INTEGER NOT NULL,
    category TEXT,
    location TEXT,
    icon TEXT DEFAULT 'palette',
    color TEXT DEFAULT '#059669',
    discount_pct INTEGER DEFAULT 0,
    stock INTEGER DEFAULT 1,
    active BOOLEAN DEFAULT TRUE,
    starts_at TIMESTAMPTZ DEFAULT NOW(),
    ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 10. VERIFICATION REQUESTS ──
CREATE TABLE IF NOT EXISTS public.verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT,
    id_type TEXT DEFAULT 'cin' CHECK (id_type IN ('cin', 'passport', 'permis')),
    front_photo_url TEXT,
    back_photo_url TEXT,
    selfie_photo_url TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reject_reason TEXT,
    reviewed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 11. REVIEWS ──
CREATE TABLE IF NOT EXISTS public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reviewer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    seller_id UUID REFERENCES public.profiles(id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    video_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(reviewer_id, product_id)
);

-- ══════════════════════════════════════════════════════════
--  AUTO-UPDATE timestamps
-- ══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated ON public.profiles;
CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated ON public.products;
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated ON public.orders;
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_verif_updated ON public.verification_requests;
CREATE TRIGGER trg_verif_updated BEFORE UPDATE ON public.verification_requests
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ══════════════════════════════════════════════════════════
--  AUTO-UPDATE seller stats on new review
-- ══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_seller_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles SET
        rating_avg = (SELECT COALESCE(AVG(rating), 0) FROM public.reviews WHERE seller_id = NEW.seller_id),
        review_count = (SELECT COUNT(*) FROM public.reviews WHERE seller_id = NEW.seller_id)
    WHERE id = NEW.seller_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_review_stats ON public.reviews;
CREATE TRIGGER trg_review_stats AFTER INSERT OR UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_seller_rating();

-- ══════════════════════════════════════════════════════════
--  INCREMENT product views
-- ══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.increment_views(product_uuid UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.products SET views = views + 1 WHERE id = product_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
