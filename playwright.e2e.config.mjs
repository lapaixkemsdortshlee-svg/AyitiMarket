// Playwright konfigirasyon, tès END-TO-END sou yon app ki deplwaye
// (Vercel preview oswa pwodiksyon). Kontrèman ak playwright.config.mjs
// (ki sèvi index.html statik lokalman), sa a frape yon URL reyèl epi li
// bezwen idantifyan (login).
//
// Varyab anviwònman (mete yo kòm GitHub Secrets pou workflow e2e.yml):
//   AYM_E2E_URL       URL app la deplwaye a (egz. https://ayiti-market.vercel.app)
//   AYM_E2E_EMAIL     imèl yon kont test achtè
//   AYM_E2E_PASSWORD  modpas kont test la
//   AYM_BYPASS_TOKEN  (opsyonèl) Vercel protection-bypass token pou preview prive
//
// Kouri: npx playwright test --config playwright.e2e.config.mjs

import { defineConfig, devices } from '@playwright/test';
import { existsSync } from 'node:fs';

const BASE_URL = process.env.AYM_E2E_URL;
const BYPASS = process.env.AYM_BYPASS_TOKEN;
const LOCAL_CHROME = '/opt/pw-browsers/chromium';
const useLocalChrome = !process.env.CI && existsSync(LOCAL_CHROME);

export default defineConfig({
    testDir: './tests/e2e',
    fullyParallel: false,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: 1,
    timeout: 60_000,
    expect: { timeout: 15_000 },
    reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
    use: {
        baseURL: BASE_URL,
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
        // Vercel "Deployment Protection" bypass, si yon token bay.
        ...(BYPASS ? {
            extraHTTPHeaders: {
                'x-vercel-protection-bypass': BYPASS,
                'x-vercel-set-bypass-cookie': 'true',
            },
        } : {}),
    },
    projects: [
        {
            name: 'chromium',
            use: {
                ...devices['Desktop Chrome'],
                ...(useLocalChrome ? { launchOptions: { executablePath: LOCAL_CHROME } } : {}),
            },
        },
    ],
    // Pa gen webServer, tès yo frape URL deplwaye a dirèkteman.
});
