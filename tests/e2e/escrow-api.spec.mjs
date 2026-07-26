// Tès END-TO-END nivo API sou vrè backend Supabase la, li kondwi tout
// machin nan eta escrow ak vrè jeton wòl yo (achtè / vandè / admin),
// epi li netwaye dèyè l. Sa valide advance_order_status + gad PR #94
// (idempotans + vèwou eta final) san depann de navigatè a.
//
// Kouri SÈLMAN lè tout idantifyan yo bay (otreman skip):
//   AYM_E2E_SB_URL       URL Supabase (egz. https://xxxx.supabase.co)
//   AYM_E2E_ANON_KEY     kle anon Supabase
//   AYM_E2E_SERVICE_KEY  kle service_role (pou kreye/efase kòmand tès)
//   AYM_E2E_BUYER_EMAIL / AYM_E2E_BUYER_PASSWORD
//   AYM_E2E_ADMIN_EMAIL / AYM_E2E_ADMIN_PASSWORD
//   AYM_E2E_SELLER_EMAIL / AYM_E2E_SELLER_PASSWORD
//
// Kouri: npx playwright test --config playwright.e2e.config.mjs escrow-api

import { test, expect } from '@playwright/test';

const E = process.env;
const SB = E.AYM_E2E_SB_URL;
const ANON = E.AYM_E2E_ANON_KEY;
const SVC = E.AYM_E2E_SERVICE_KEY;
const creds = {
    buyer: [E.AYM_E2E_BUYER_EMAIL, E.AYM_E2E_BUYER_PASSWORD],
    admin: [E.AYM_E2E_ADMIN_EMAIL, E.AYM_E2E_ADMIN_PASSWORD],
    seller: [E.AYM_E2E_SELLER_EMAIL, E.AYM_E2E_SELLER_PASSWORD],
};
const ready = Boolean(SB && ANON && SVC &&
    creds.buyer[0] && creds.buyer[1] && creds.admin[0] && creds.admin[1] &&
    creds.seller[0] && creds.seller[1]);

test.skip(!ready, 'E2E escrow API: idantifyan absan (gade tèt fichye a).');

async function api(method, path, token, body, key = ANON) {
    const headers = { apikey: key, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
    if (['POST', 'PATCH', 'DELETE'].includes(method)) headers.Prefer = 'return=representation';
    const res = await fetch(SB + path, { method, headers, body: body != null ? JSON.stringify(body) : undefined });
    const text = await res.text();
    return { status: res.status, data: text ? JSON.parse(text) : null };
}
async function login(email, password) {
    const { status, data } = await api('POST', '/auth/v1/token?grant_type=password', '', { email, password });
    expect(status, `login ${email}`).toBe(200);
    return { token: data.access_token, id: data.user.id };
}
const adv = (tok, id, to, ref, note) =>
    api('POST', '/rest/v1/rpc/advance_order_status', tok,
        { p_order_id: id, p_to_status: to, p_moncash_ref: ref ?? null, p_admin_note: note ?? null });

test('escrow: lifecycle konplè + idempotans + vèwou final + litij', async () => {
    test.setTimeout(60_000);
    const buyer = await login(...creds.buyer);
    const admin = await login(...creds.admin);
    const seller = await login(...creds.seller);

    const TAG = `E2E-QA-${Date.now()}`;
    const made = [];
    const mkOrder = async (status, otp = '123456') => {
        const { status: st, data } = await api('POST', '/rest/v1/orders', SVC, [{
            buyer_id: buyer.id, seller_id: seller.id, buyer_name: 'QA', seller_name: 'QA',
            product_title: TAG, quantity: 1, unit_price: 100, total_amount: 100,
            fee_amount: 3, net_amount: 97, status, otp_code: otp,
        }], SVC);
        expect(st, 'create order').toBe(201);
        const id = data[0].id; made.push(id); return id;
    };

    try {
        // ── Happy path ──
        const A = await mkOrder('awaiting_payment');
        expect((await adv(buyer.token, A, 'payment_submitted', 'QAREF')).data.status).toBe('payment_submitted');
        expect((await adv(admin.token, A, 'payment_verified')).data.status).toBe('payment_verified');
        expect((await adv(seller.token, A, 'ready_for_pickup')).data.status).toBe('ready_for_pickup');
        const otp = await api('POST', '/rest/v1/rpc/try_seller_otp', seller.token, { p_order_id: A, p_otp: '123456' });
        expect(otp.data.ok).toBe(true);
        expect((await adv(admin.token, A, 'released')).data.status).toBe('released');

        // ── Idempotence (PR #94): re-release = no-op, pa dedouble odit ──
        const before = (await api('GET', `/rest/v1/admin_actions?order_id=eq.${A}&select=id`, admin.token)).data.length;
        expect((await adv(admin.token, A, 'released')).data.status).toBe('released');
        const after = (await api('GET', `/rest/v1/admin_actions?order_id=eq.${A}&select=id`, admin.token)).data.length;
        expect(after, 'no duplicate audit row').toBe(before);

        // ── Vèwou eta final (PR #94): refunded -> released dwe bloke ──
        const B = await mkOrder('refunded');
        const blocked = await adv(admin.token, B, 'released');
        expect(blocked.status).toBe(400);
        expect(String(blocked.data.message)).toMatch(/final state/i);

        // ── Litij: achtè ouvri, admin rezoud ──
        const C = await mkOrder('otp_confirmed');
        expect((await adv(buyer.token, C, 'disputed', '', 'QA rezon')).data.status).toBe('disputed');
        expect((await adv(admin.token, C, 'refunded', null, 'QA resolve')).data.status).toBe('refunded');
    } finally {
        // ── Netwayaj ──
        for (const id of made) {
            await api('DELETE', `/rest/v1/admin_actions?order_id=eq.${id}`, SVC, null, SVC);
            await api('DELETE', `/rest/v1/orders?id=eq.${id}`, SVC, null, SVC);
        }
    }
});
