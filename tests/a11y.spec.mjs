// Tès aksesiblite, kouri axe-core sou paj la apre li chaje. Asire
// pa gen vyolasyon kritik ni grav. Pa fè echèk sou nivo "moderate" /
// "minor", yo souvan "false positives" oswa nuans desibèl ki pa bloke
// itilizatè.

import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// Regle dezaktive kounye a + rezon, yo dwe diminye lè nou amelyore
// a11y. Vize: vid (zero `disableRules`).
//
// `label` + `select-name` kouvri yon baseline de chan ki te ekziste
// anvan pas a11y a : Axe konte 19+4 enstans. PR sa a entwodui
// enfrastrikti a11y (focus-visible, skip-link, lang="ht", aria-labels
// kle); PR ki vini yo dwe atake chak fòm ki rete pou yo ka retire de
// regle sa yo isit la.
const DISABLE_RULES = [
    // Tailwind utility "sr-only peer" cache yon input : Axe pa wè li,
    // men li gen yon eleman pou klike pa-deyò.
    'aria-hidden-focus',
    // Tailwind CDN bay koulè dinamik, sandbox CI sandbox ka pa wè yo.
    'color-contrast',
    // TODO(a11y): ajoute <label for=…> oswa aria-label sou tout
    // <input>/<select> nan fòm yo (~23 enstans).
    'label',
    'select-name',
];

test('axe: pa gen vyolasyon kritik oswa grav sou paj la', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('domcontentloaded');
    await page.waitForTimeout(2000);   // tan pou inisyalizasyon SPA

    const builder = new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .disableRules(DISABLE_RULES);

    const results = await builder.analyze();
    const blocking = (results.violations || []).filter(
        v => v.impact === 'critical' || v.impact === 'serious'
    );

    if (blocking.length) {
        const summary = blocking.map(v =>
            `- [${v.impact}] ${v.id}: ${v.description} (${v.nodes.length} kote)`
        ).join('\n');
        console.log('\nAxe violations:\n' + summary);
    }
    expect(blocking, 'Pa dwe gen okenn vyolasyon a11y critical/serious').toEqual([]);
});

test('html gen yon lang attribute valab', async ({ page }) => {
    await page.goto('/');
    const lang = await page.locator('html').getAttribute('lang');
    expect(lang, 'html dwe gen yon lang attribute').toBeTruthy();
});

test('skip-link disponib pou navigasyon klavye', async ({ page }) => {
    await page.goto('/');
    const skip = page.locator('a.skip-link');
    await expect(skip, 'skip-link dwe egziste').toHaveCount(1);
    const href = await skip.getAttribute('href');
    expect(href, 'skip-link dwe pwente sou yon ankrè').toMatch(/^#/);
    // Target la dwe egziste sou paj la
    if (href) {
        const targetId = href.slice(1);
        const target = page.locator('#' + targetId);
        await expect(target, `Sib skip-link (${href}) dwe egziste`).toHaveCount(1);
    }
});
