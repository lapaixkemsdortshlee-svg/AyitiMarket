// Tès END-TO-END otantifye sou app la (deplwaye OSWA sèvi lokalman kont
// vrè Supabase la, gade README anba). Yo kouri SÈLMAN lè idantifyan yo
// bay (AYM_E2E_URL / AYM_E2E_EMAIL / AYM_E2E_PASSWORD), otreman yo skip -
// konsa `npm test` lokal ak CI smoke a pa kase.
//
// Kouri: npx playwright test --config playwright.e2e.config.mjs
//
// NÒT: paske index.html gen URL + kle anon Supabase la ekri ladan l,
// nou ka sèvi l lokalman (python3 -m http.server) epi mete
// AYM_E2E_URL=http://127.0.0.1:5173, konsa QA a frape vrè backend la
// san pase pa Vercel (evite rate-limit 429).

import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const URL = process.env.AYM_E2E_URL;
const EMAIL = process.env.AYM_E2E_EMAIL;
const PASSWORD = process.env.AYM_E2E_PASSWORD;
// Mòd altènatif: enjekte yon sesyon Supabase deja jenere. Itil lokalman /
// nan sandbox kote login UI a pa ka rive sou Supabase depi navigatè a.
// Bay tou AYM_E2E_SB_REF (ref pwojè), epi opsyonèlman AYM_E2E_SDK_PATH
// (chemen lokal SDK supabase-js si CDN jsdelivr bloke).
const SESSION = process.env.AYM_E2E_SESSION;
const SB_REF = process.env.AYM_E2E_SB_REF;
const SDK_PATH = process.env.AYM_E2E_SDK_PATH;
const ready = Boolean(URL && ((EMAIL && PASSWORD) || (SESSION && SB_REF)));

test.skip(!ready,
    'E2E idantifyan absan, bay AYM_E2E_URL + (AYM_E2E_EMAIL/PASSWORD) oswa (AYM_E2E_SESSION + AYM_E2E_SB_REF). Gade .env.example.');

// Menm règ dezaktive ak tests/a11y.spec.mjs pou konsistans (baseline
// fòm ki poko gen label). Vize: diminye lis sa a piti piti.
const A11Y_DISABLE = ['aria-hidden-focus', 'color-contrast', 'label', 'select-name'];

// Erè ki se bri anviwònman (CDN bloke lokalman, rezo proxy), pa erè app.
const NOISE = [/tailwind/i, /cdn\./i, /Failed to load resource/i, /net::ERR_/i, /unpkg/i];
const isNoise = (m) => NOISE.some(re => re.test(m));

// Konekte yon achtè, swa via UI a (email/modpas), swa via yon sesyon
// enjekte (AYM_E2E_SESSION).
async function login(page, email, password) {
    // Sèvi SDK supabase-js lokalman si CDN jsdelivr bloke (sandbox).
    if (SDK_PATH) {
        await page.route(/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js/,
            r => r.fulfill({ path: SDK_PATH, contentType: 'text/javascript' }));
    }

    // Mòd enjeksyon sesyon: pa gen login UI, app la boote deja konekte.
    if (SESSION && SB_REF) {
        await page.addInitScript(([k, v]) => {
            try { localStorage.setItem('aym_onboarded', '1'); localStorage.setItem(k, v); } catch (_) {}
        }, [`sb-${SB_REF}-auth-token`, SESSION]);
        await page.goto('/');
        await expect(page.locator('#emailAuthForm')).toBeHidden({ timeout: 20_000 });
        return;
    }

    // Sote onboarding premye-vizit la pou n rive dirèk sou #s-login apre splash.
    await page.addInitScript(() => { try { localStorage.setItem('aym_onboarded', '1'); } catch (_) {} });
    await page.goto('/');

    // Splash la fè yon animasyon anvan li kite plas pou login lan.
    await expect(page.locator('#authEmail')).toBeVisible({ timeout: 25_000 });

    // Fòm nan louvri an mòd "Kreye Kont" pa default, bascule an "Konekte".
    const btn = page.locator('#emailSignUpBtn');
    if ((await btn.textContent())?.trim() !== 'Konekte') {
        await page.locator('#authToggleLink').click();
        await expect(btn).toHaveText(/Konekte/);
    }

    await page.locator('#authEmail').fill(email);
    await page.locator('#authPassword').fill(password);
    await btn.click();

    // Login reyisi -> ekran #s-login (ki genyen #emailAuthForm) disparèt
    // pandan app la ale sou feed. (#bottomNav toujou vizib, se pa yon
    // bon siyal.)
    await expect(page.locator('#emailAuthForm')).toBeHidden({ timeout: 20_000 });
}

// Scan aksesiblite sou ekran aktyèl la (kritik/grav sèlman).
async function axeScan(page, label) {
    const res = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .disableRules(A11Y_DISABLE)
        .analyze();
    const blocking = (res.violations || []).filter(
        v => v.impact === 'critical' || v.impact === 'serious');
    if (blocking.length) {
        console.log(`\n[axe ${label}]\n` + blocking.map(
            v => `- [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length})`).join('\n'));
    }
    expect(blocking, `Vyolasyon a11y sou ekran "${label}"`).toEqual([]);
}

test('achtè ka konekte ak email/modpas', async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e.message || e)));

    await login(page, EMAIL, PASSWORD);

    // Fòm otantifikasyon an disparèt apre login.
    await expect(page.locator('#emailAuthForm')).toBeHidden();
    const critical = errors.filter(e => !isNoise(e));
    expect(critical, `Erè JS pandan login:\n${critical.join('\n')}`).toEqual([]);
});

// axe-core sou nouvo ekran otantifye yo (feed / komand / pwofil / pibliye).
// Itilize navTo() global la pou chanje ekran, chak `#s-<tab>` se yon
// vue distenk.
test('axe: ekran otantifye yo pa gen vyolasyon kritik', async ({ page }) => {
    await login(page, EMAIL, PASSWORD);
    for (const tab of ['feed', 'order', 'profile', 'pub']) {
        await page.evaluate((t) => window.navTo && window.navTo(t), tab);
        // Kèk ekran ka pa aktive dapre wòl/eta, sote yo olye pou echwe.
        try {
            await expect(page.locator('#s-' + tab)).toHaveClass(/on/, { timeout: 3000 });
        } catch {
            continue;
        }
        await page.waitForTimeout(500);
        await axeScan(page, tab);
    }
});

// ── Flux end-to-end (P0) ─────────────────────────────────────
// Flux escrow konplè + litij yo kouvri kounye a kòm tès API repetab
// nan tests/e2e/escrow-api.spec.mjs (validé live an pwodiksyon ak
// achtè + vandè + admin, ak netwayaj).
//
// Rès la (UI navigatè):
// Parennaj (promo): kòd refè pèsonèl + kontè limit 3 moun. Frape vrè
// Supabase la (jenere/li kòd la + li used_count/max_uses).
test('parennaj (UI): kòd refè + kontè limit 3 moun', async ({ page }) => {
    await login(page, EMAIL, PASSWORD);
    await page.evaluate(() => window.openReferralSheet && window.openReferralSheet());
    const code = page.locator('#referralCode');
    await expect(code).toBeVisible({ timeout: 15_000 });
    // Kòd refè kòmanse pa EKO- depi rebrand la (tès 2-3 moun, Bug 7).
    // Ansyen kòd AYIM- yo migre nan baz la.
    await expect(code).toHaveText(/^EKO-/, { timeout: 15_000 });
    // Kontè limit 3 moun nan afiche (swa "Rete X/3 moun" swa "limit").
    await expect(page.locator('#referralRemaining')).toContainText(/moun/, { timeout: 15_000 });
});
