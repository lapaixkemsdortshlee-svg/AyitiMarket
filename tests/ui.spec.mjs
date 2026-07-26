// Tès UI san backend, yo egzèse sa ki rann + lojik kliyan sèlman
// (pa gen Supabase / auth). Konplete smoke.spec.mjs (chajman paj) ak
// a11y.spec.mjs (aksesiblite) ak kèk garanti sou:
//   1. Meta / PWA (SEO + enstalasyon)
//   2. Manifest + ikòn yo sèvi
//   3. Fòm otantifikasyon an prezan (pòt antre kritik la)
//   4. Lojik toggleAuthMode() (login <-> signup), pi rich kòm konpòtman
//   5. Fichye antre + asset kle yo sèvi (pa 404)

import { test, expect } from '@playwright/test';

test.describe('Meta / PWA integrity', () => {
    test('head gen meta esansyèl yo', async ({ page }) => {
        await page.goto('/');
        await expect(page).toHaveTitle(/Ekomat/i);
        await expect(page.locator('meta[name="viewport"]')).toHaveAttribute('content', /width=device-width/i);
        await expect(page.locator('meta[name="description"]')).toHaveAttribute('content', /Ekomat|[Mm]arketplace/);
        await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', /#00666f/i);
        await expect(page.locator('link[rel="manifest"]')).toHaveCount(1);
    });

    test('head gen Open Graph pou pataj sosyal', async ({ page }) => {
        await page.goto('/');
        await expect(page.locator('meta[property="og:title"]')).toHaveAttribute('content', /Ekomat/i);
        await expect(page.locator('meta[property="og:image"]')).toHaveAttribute('content', /https?:\/\/.+\.(png|jpg|jpeg|webp)/i);
        await expect(page.locator('meta[property="og:type"]')).toHaveCount(1);
        await expect(page.locator('meta[name="twitter:card"]')).toHaveCount(1);
        await expect(page.locator('link[rel="apple-touch-icon"]')).toHaveCount(1);
    });

    test('manifest gen yon non + ikòn ki sèvi', async ({ request }) => {
        const res = await request.get('/manifest.json');
        expect(res.status()).toBeLessThan(400);
        const m = await res.json();
        expect(m.name || m.short_name, 'manifest dwe gen yon non').toBeTruthy();
        expect(Array.isArray(m.icons) && m.icons.length > 0, 'manifest dwe gen ikòn').toBeTruthy();
        // Chak ikòn ki nan manifest la dwe sèvi (pa 404).
        for (const icon of m.icons) {
            const src = icon.src.startsWith('/') ? icon.src : '/' + icon.src;
            const r = await request.get(src);
            expect(r.status(), `${icon.src} dwe sèvi`).toBeLessThan(400);
        }
    });
});

test.describe('Otantifikasyon (san backend)', () => {
    test('fòm otantifikasyon an prezan nan DOM', async ({ page }) => {
        await page.goto('/');
        await page.waitForTimeout(1500);
        for (const id of ['#emailAuthForm', '#authEmail', '#authPassword', '#emailSignUpBtn', '#authToggleLink']) {
            await expect(page.locator(id), `${id} dwe egziste`).toHaveCount(1);
        }
        // Chan modpas la dwe yon vrè input password.
        await expect(page.locator('#authPassword')).toHaveAttribute('type', 'password');
    });

    test('toggleAuthMode() chanje ant Kreye Kont ak Konekte', async ({ page }) => {
        await page.goto('/');
        await page.waitForTimeout(1500);
        const btn = page.locator('#emailSignUpBtn');

        const initial = (await btn.textContent())?.trim();
        expect(['Kreye Kont', 'Konekte']).toContain(initial);

        await page.evaluate(() => toggleAuthMode());
        const after = (await btn.textContent())?.trim();
        expect(after, 'label dwe chanje apre yon toggle').not.toBe(initial);
        expect(['Kreye Kont', 'Konekte']).toContain(after);

        await page.evaluate(() => toggleAuthMode());
        const back = (await btn.textContent())?.trim();
        expect(back, 'label dwe retounen apre dezyèm toggle').toBe(initial);
    });
});

test.describe('Mòd envite (san backend)', () => {
    test('enterGuestMode montre feed la epi kache aksyon konekte yo', async ({ page }) => {
        await page.goto('/');
        await page.waitForTimeout(1500);
        // Bouton "Gade katalòg la san kont" dwe la sou ekran login.
        await expect(page.getByText('Gade katalòg la san kont')).toHaveCount(1);
        await page.evaluate(() => window.enterGuestMode());
        await page.waitForTimeout(300);
        await expect(page.locator('#s-feed')).toHaveClass(/on/);
        // FAB pibliye + bouton mesaj/notif yo kache pou envite.
        await expect(page.locator('#fab')).toHaveClass(/hidden/);
        await expect(page.locator('#msgBtn')).toHaveClass(/hidden/);
        expect(await page.evaluate(() => typeof window.requireLogin === 'function')).toBe(true);
    });

    test('yon aksyon gated (kòmande) mennen envite sou login', async ({ page }) => {
        await page.goto('/');
        await page.waitForTimeout(1500);
        await page.evaluate(() => window.enterGuestMode());
        await page.waitForTimeout(200);
        // Kòmande kòm envite dwe rale ekran koneksyon an (pa kraze).
        await page.evaluate(() => window.startOrder('nonexistent-id'));
        await page.waitForTimeout(200);
        await expect(page.locator('#s-login')).toHaveClass(/on/);
    });
});

test('fichye antre + asset kle yo sèvi', async ({ request }) => {
    for (const path of ['/', '/onboarding.html', '/icon-192.png', '/icon-512.png', '/og-image.png',
        '/robots.txt', '/sitemap.xml', '/llms.txt', '/l/elektwonik.html', '/l/potoprens.html']) {
        const r = await request.get(path);
        expect(r.status(), `${path} dwe sèvi`).toBeLessThan(400);
    }
});
