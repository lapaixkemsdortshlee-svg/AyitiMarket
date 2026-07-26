// Playwright konfigirasyon, smoke tests sou static index.html la.
//
// Sèvi ak python3 -m http.server 5173 pou sèvi fichye yo lokalman.
// Sou CI, fòs `reuseExistingServer:false` pou nou pa konekte sou yon
// sèvè ki t ap mache deja sou yon ekzekisyon presedan.

import { defineConfig, devices } from '@playwright/test';
import { existsSync } from 'node:fs';

const PORT = 5173;
const BASE_URL = process.env.AYM_TEST_URL || `http://127.0.0.1:${PORT}`;

// Sou anviwònman sandbox la, Playwright kapab pa gen menm vèsyon ak
// chromium ki preanstale a. Si nou jwenn yon binè lokal epi nou pa sou
// CI, sèvi ak li dirèkteman pou evite telechaje yon nouvo navigatè.
const LOCAL_CHROME = '/opt/pw-browsers/chromium';
const useLocalChrome = !process.env.CI && existsSync(LOCAL_CHROME);

export default defineConfig({
    testDir: './tests',
    // Tès e2e otantifye yo gen pwòp config yo (playwright.e2e.config.mjs)
    // epi yo frape yon URL deplwaye, pa enkli yo nan smoke run lokal/CI.
    testIgnore: ['**/e2e/**'],
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    workers: process.env.CI ? 1 : undefined,
    timeout: 30_000,
    expect: { timeout: 5_000 },
    reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
    use: {
        baseURL: BASE_URL,
        trace: 'on-first-retry',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure',
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
    // Lè AYM_TEST_URL fikse (egz. yon URL Vercel preview), pa demare okenn sèvè.
    webServer: process.env.AYM_TEST_URL ? undefined : {
        command: `python3 -m http.server ${PORT}`,
        url: `http://127.0.0.1:${PORT}`,
        reuseExistingServer: !process.env.CI,
        timeout: 60_000,
    },
});
