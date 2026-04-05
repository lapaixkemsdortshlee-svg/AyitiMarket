-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Row Level Security (RLS) Policies
--  Execute AFTER schema.sql in: Supabase > SQL Editor
-- ══════════════════════════════════════════════════════════

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flash_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════════════════════════
--  Helper: check if user is admin
-- ══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ══════════════════════════════════════════════════════════
--  PROFILES
-- ══════════════════════════════════════════════════════════
-- Anyone can read profiles (public marketplace)
CREATE POLICY "profiles_select_public" ON public.profiles
    FOR SELECT USING (true);

-- Users can update their own profile
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile (signup)
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Admin can update any profile (verification, bans)
CREATE POLICY "profiles_admin_update" ON public.profiles
    FOR UPDATE USING (public.is_admin());

-- ══════════════════════════════════════════════════════════
--  PRODUCTS
-- ══════════════════════════════════════════════════════════
-- Anyone can read active products
CREATE POLICY "products_select_active" ON public.products
    FOR SELECT USING (status = 'active' OR seller_id = auth.uid() OR public.is_admin());

-- Sellers can insert their own products
CREATE POLICY "products_insert_seller" ON public.products
    FOR INSERT WITH CHECK (auth.uid() = seller_id);

-- Sellers can update their own products
CREATE POLICY "products_update_own" ON public.products
    FOR UPDATE USING (auth.uid() = seller_id OR public.is_admin());

-- Sellers can delete their own products
CREATE POLICY "products_delete_own" ON public.products
    FOR DELETE USING (auth.uid() = seller_id OR public.is_admin());

-- ══════════════════════════════════════════════════════════
--  ORDERS
-- ══════════════════════════════════════════════════════════
-- Buyers see their orders, sellers see orders for their products
CREATE POLICY "orders_select_own" ON public.orders
    FOR SELECT USING (
        auth.uid() = buyer_id OR
        auth.uid() = seller_id OR
        public.is_admin()
    );

-- Buyers can create orders
CREATE POLICY "orders_insert_buyer" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- Sellers and admin can update order status
CREATE POLICY "orders_update" ON public.orders
    FOR UPDATE USING (
        auth.uid() = seller_id OR
        auth.uid() = buyer_id OR
        public.is_admin()
    );

-- ══════════════════════════════════════════════════════════
--  CART ITEMS
-- ══════════════════════════════════════════════════════════
-- Users see only their cart
CREATE POLICY "cart_select_own" ON public.cart_items
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "cart_insert_own" ON public.cart_items
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cart_update_own" ON public.cart_items
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "cart_delete_own" ON public.cart_items
    FOR DELETE USING (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════
--  MESSAGES
-- ══════════════════════════════════════════════════════════
-- Users see messages they sent or received
CREATE POLICY "messages_select_own" ON public.messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Users can send messages
CREATE POLICY "messages_insert_sender" ON public.messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Users can mark their received messages as read
CREATE POLICY "messages_update_read" ON public.messages
    FOR UPDATE USING (auth.uid() = receiver_id);

-- ══════════════════════════════════════════════════════════
--  FAVORITES
-- ══════════════════════════════════════════════════════════
CREATE POLICY "favorites_select_own" ON public.favorites
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert_own" ON public.favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_delete_own" ON public.favorites
    FOR DELETE USING (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════
--  FOLLOWERS
-- ══════════════════════════════════════════════════════════
-- Anyone can see follower counts (public)
CREATE POLICY "followers_select_public" ON public.followers
    FOR SELECT USING (true);

CREATE POLICY "followers_insert_own" ON public.followers
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "followers_delete_own" ON public.followers
    FOR DELETE USING (auth.uid() = follower_id);

-- ══════════════════════════════════════════════════════════
--  NOTIFICATIONS
-- ══════════════════════════════════════════════════════════
CREATE POLICY "notifications_select_own" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- System/admin can insert notifications for any user
CREATE POLICY "notifications_insert" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "notifications_update_own" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════
--  FLASH DEALS
-- ══════════════════════════════════════════════════════════
-- Anyone can see active flash deals
CREATE POLICY "flash_deals_select_active" ON public.flash_deals
    FOR SELECT USING (active = true OR public.is_admin());

-- Only admin can manage flash deals
CREATE POLICY "flash_deals_admin_insert" ON public.flash_deals
    FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "flash_deals_admin_update" ON public.flash_deals
    FOR UPDATE USING (public.is_admin());

CREATE POLICY "flash_deals_admin_delete" ON public.flash_deals
    FOR DELETE USING (public.is_admin());

-- ══════════════════════════════════════════════════════════
--  VERIFICATION REQUESTS
-- ══════════════════════════════════════════════════════════
-- Users see their own requests, admin sees all
CREATE POLICY "verif_select" ON public.verification_requests
    FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

-- Users can submit verification
CREATE POLICY "verif_insert_own" ON public.verification_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Only admin can update verification status
CREATE POLICY "verif_admin_update" ON public.verification_requests
    FOR UPDATE USING (public.is_admin());

-- ══════════════════════════════════════════════════════════
--  REVIEWS
-- ══════════════════════════════════════════════════════════
-- Anyone can read reviews (public)
CREATE POLICY "reviews_select_public" ON public.reviews
    FOR SELECT USING (true);

-- Users can write reviews for products they bought
CREATE POLICY "reviews_insert_own" ON public.reviews
    FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

CREATE POLICY "reviews_update_own" ON public.reviews
    FOR UPDATE USING (auth.uid() = reviewer_id);

-- ══════════════════════════════════════════════════════════
--  ENABLE REALTIME for chat & notifications
-- ══════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
