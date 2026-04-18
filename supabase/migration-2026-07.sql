-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Migration 2026-07 — Notifications RLS complete
--  Execute via: Supabase Dashboard > SQL Editor > New Query
--  SAFE to re-run: every change is idempotent.
--
--  Fixes:
--    • notifications: add missing SELECT + UPDATE policies
--      (users could never read their own notifications without these)
--    • notifications: ensure INSERT allows cross-user writes
--    • notifications: enable REPLICA IDENTITY FULL for Realtime
--    • profiles: ensure SELECT is open to all authenticated users
--      (needed for inbox names, chat partners, seller pages)
-- ══════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────
-- 1) NOTIFICATIONS — full RLS suite
-- ──────────────────────────────────────────────────────────

-- Enable RLS (idempotent)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: each user sees only their own notifications
DROP POLICY IF EXISTS "notifications_select_own"  ON public.notifications;
CREATE POLICY "notifications_select_own" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

-- INSERT: any authenticated user can insert (needed for cross-user notifs)
DROP POLICY IF EXISTS "notifications_insert"      ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_any"  ON public.notifications;
CREATE POLICY "notifications_insert_any" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- UPDATE: only the owner can mark as read
DROP POLICY IF EXISTS "notifications_update_own"  ON public.notifications;
CREATE POLICY "notifications_update_own" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- DELETE: owner can clear their own notifications
DROP POLICY IF EXISTS "notifications_delete_own"  ON public.notifications;
CREATE POLICY "notifications_delete_own" ON public.notifications
    FOR DELETE USING (auth.uid() = user_id);

-- Enable full replica identity so Realtime can filter by user_id
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- ──────────────────────────────────────────────────────────
-- 2) PROFILES — ensure all authenticated users can read profiles
--    (required for inbox names, chat partner info, seller pages)
-- ──────────────────────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
CREATE POLICY "profiles_select_authenticated" ON public.profiles
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Users can only update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ──────────────────────────────────────────────────────────
-- 3) MESSAGES — ensure users can read messages they are part of
-- ──────────────────────────────────────────────────────────

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_participant" ON public.messages;
CREATE POLICY "messages_select_participant" ON public.messages
    FOR SELECT USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
        OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
    );

DROP POLICY IF EXISTS "messages_insert_sender" ON public.messages;
CREATE POLICY "messages_insert_sender" ON public.messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "messages_update_receiver" ON public.messages;
CREATE POLICY "messages_update_receiver" ON public.messages
    FOR UPDATE USING (auth.uid() = receiver_id OR auth.uid() = sender_id)
    WITH CHECK (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- Enable Realtime for messages
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- ══════════════════════════════════════════════════════════
--  Verification:
--    SELECT policyname, cmd FROM pg_policies WHERE tablename='notifications';
--    SELECT policyname, cmd FROM pg_policies WHERE tablename='profiles';
--    SELECT policyname, cmd FROM pg_policies WHERE tablename='messages';
-- ══════════════════════════════════════════════════════════
