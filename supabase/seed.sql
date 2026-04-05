-- ══════════════════════════════════════════════════════════
--  AyitiMarket — Seed Data (Premier produit reel)
--  Execute AFTER schema.sql + rls-policies.sql
--
--  NOTE: Remplace le seller_id par le UUID reel d'un
--  vendeur verifie dans ta base (Dashboard > Auth > Users)
-- ══════════════════════════════════════════════════════════

-- ── Example: Insert products for a verified seller ──
-- Replace 'SELLER_UUID_HERE' with an actual seller UUID from auth.users

/*
INSERT INTO public.products (seller_id, title, description, price, category, location, stock, sizes) VALUES
    ('SELLER_UUID_HERE', 'Wòb Swaré Elegant', 'Wòb elegant fèt alamen pa atizàn ayisyen. Twal kalite siperyè, fini swayen. Disponib nan plizye tay. Livrezon PAP disponib.', 3500, 'mode', 'Pétion-Ville', 8, ARRAY['XS','S','M','L']),
    ('SELLER_UUID_HERE', 'Sèwom Eklatan Natirèl', 'Sèwom natirèl ak plant ayisyen. Klere po an 2 semèn. Engredyan 100% natirèl, san pwodwi chimik.', 1800, 'cosmetique', 'Pétion-Ville', 12, '{}'),
    ('SELLER_UUID_HERE', 'Kolye Atizana Ò', 'Kolye ò 18 kara, pyes inik fèt pa bijoutye ayisyen. Idyal kòm kado.', 2800, 'accessoire', 'Delmas', 3, '{}'),
    ('SELLER_UUID_HERE', 'Sak Pay Trese', 'Sak atizanal pay trese, fèt pa artizàn lokal. Motif tradisyonèl ayisyen.', 3200, 'artisanat', 'Pétion-Ville', 6, '{}'),
    ('SELLER_UUID_HERE', 'Krèm Karite 100% Natirèl', 'Krèm natirèl karite ayisyen. 100% natirèl. Pou tout kalite po. Idrate ak pwoteje.', 950, 'cosmetique', 'Carrefour', 24, '{}'),
    ('SELLER_UUID_HERE', 'Chemiz Brode Tradisyonèl', 'Chemiz brode alamen. Motif tradisyonèl ayisyen. Koton kalite siperyè.', 2800, 'mode', 'Tabarre', 4, ARRAY['S','M','L','XL']),
    ('SELLER_UUID_HERE', 'Pak Rad Bebe x10', 'Pak 10 rad pou bebe 0-12 mwa. Koton 100%. Dou ak konfòtab pou timoun.', 1200, 'bebe', 'Delmas', 15, ARRAY['0-3M','3-6M','6-12M']),
    ('SELLER_UUID_HERE', 'Tablo Penti Ayisyen', 'Tablo atizanal ayisyen, pent alamen. Pyes inik ki montre kilti ak bote peyi a.', 5200, 'artisanat', 'Pétion-Ville', 2, '{}');
*/

-- ══════════════════════════════════════════════════════════
--  QUICK START GUIDE:
--
--  1. Run schema.sql first
--  2. Run rls-policies.sql
--  3. Create a user account via your app (Google or Email)
--  4. In Supabase Dashboard > Table Editor > profiles:
--     - Find your user, set role='seller', verified_seller=true
--  5. Copy that user's UUID
--  6. Uncomment the INSERT above, replace SELLER_UUID_HERE
--  7. Run this file
--  8. Your products will appear on the feed!
-- ══════════════════════════════════════════════════════════
