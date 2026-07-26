// Smoke tests pou Ekomat. Yo verifye:
//   1. App la chaje san erè JavaScript kritik
//   2. Tit paj la kòrèk
//   3. UI prensipal la (splash / login / feed) parèt
//   4. Service worker fichye yo sèvi (pa 404)
//
// Yo *pa* eseye konekte oswa fè kòmand, sa ta mande Supabase + auth.
// Pou tès end-to-end pi pwofon, kreye yon `tests/e2e/*.spec.mjs`
// separe pi devan.

import { test, expect } from '@playwright/test';

const KNOWN_NOISE = [
    /supabase/i,
    /firebase/i,
    /fcm/i,
    /moncash/i,
    /sw\.js/i,
    /tile\.openstreetmap/i,
    /locationiq/i,
    /favicon/i,
    /gstatic/i,
    /fonts\.googleapis/i,
    /manifest\.json/i,
    /preload/i,
    // Erè rezo (proxy sandbox, CDN bloke, etc.), pa erè JS
    /failed to load resource/i,
    /net::err_/i,
    /ERR_TUNNEL_CONNECTION_FAILED/i,
    /tailwindcss/i,
    /\btailwind\b/i,
    /cdn\.jsdelivr/i,
    /cdnjs\.cloudflare/i,
];

function isNoise(msg) {
    return KNOWN_NOISE.some(re => re.test(msg));
}

test('paj la chaje san erè kritik', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e.message || e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    await page.goto('/');
    await expect(page).toHaveTitle(/Ekomat/i);

    // Bay app la tan pou inisyalize state ak charge SDK yo.
    await page.waitForTimeout(2500);

    const critical = errors.filter(e => !isNoise(e));
    expect(critical, `Erè JS kritik:\n${critical.join('\n')}`).toEqual([]);
});

test('UI Kreyòl la parèt apre chajman', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(2000);
    // Kèlkanswa eta a (splash / onboarding / login / feed), body a dwe
    // gen tèks Kreyòl ki rekonèt.
    await expect(page.locator('body')).toContainText(/Ayiti/i);
});

test('service workers + manifest aksesib', async ({ request }) => {
    const sw = await request.get('/sw.js');
    expect(sw.status(), 'sw.js dwe sèvi').toBeLessThan(400);

    const fcmSw = await request.get('/firebase-messaging-sw.js');
    expect(fcmSw.status(), 'firebase-messaging-sw.js dwe sèvi').toBeLessThan(400);

    const manifest = await request.get('/manifest.json');
    expect(manifest.status(), 'manifest.json dwe sèvi').toBeLessThan(400);
    const json = await manifest.json();
    expect(json.name || json.short_name, 'manifest dwe gen yon non').toBeTruthy();
});
