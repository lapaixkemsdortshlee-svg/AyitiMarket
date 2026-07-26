// supabase/functions/send-push/index.ts
//
// Edge Function ki voye yon vrè push FCM HTTP v1 bay tout aparèy yon
// itilizatè lè yon ranje nouvèl kreye nan tab `notifications`.
//
// FLOW:
//   1. Yon Database Webhook (Supabase Studio → Database → Webhooks) tape
//      sou URL fonksyon sa a chak fwa yon ranje `notifications` ensere,
//      epi pase yon header `x-webhook-secret` ki egal WEBHOOK_SECRET la.
//   2. Fonksyon an echanj yon JWT siyen ak kle privè service-account la
//      pou yon OAuth access token (cache nan memwa pou ~50 minit).
//   3. Pou chak ranje nan `user_devices` ki gen `user_id` koresponn lan,
//      li fè POST sou:
//        https://fcm.googleapis.com/v1/projects/{projectId}/messages:send
//   4. Si FCM retounen 404 (UNREGISTERED) oswa 400 (INVALID_ARGUMENT)
//      pou yon token, fonksyon an efase ranje a, token mò.
//
// SECRETS POU KONFIGIRE (`supabase secrets set …`):
//   FCM_SERVICE_ACCOUNT_JSON   →  kontni JSON service-account Firebase la
//   WEBHOOK_SECRET             →  yon chenn ou jenere (egz. `openssl rand -hex 32`)
//
// DEPLWAYE:
//   supabase functions deploy send-push --no-verify-jwt
//
// (Webhook la pa voye yon JWT Supabase, nou itilize WEBHOOK_SECRET la pito.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

// Cache OAuth token an memwa pandan kò fonksyon an cho. Re-itilize l
// jiskaske li gen mwens pase 60s anvan ekspire.
let _cachedToken: { value: string; expiresAt: number } | null = null;

interface ServiceAccount {
    type: string;
    project_id: string;
    private_key_id: string;
    private_key: string;
    client_email: string;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (_cachedToken && _cachedToken.expiresAt > now + 60) {
        return _cachedToken.value;
    }
    const key = await importPKCS8(sa.private_key, "RS256");
    const jwt = await new SignJWT({ scope: FCM_SCOPE })
        .setProtectedHeader({ alg: "RS256", typ: "JWT", kid: sa.private_key_id })
        .setIssuer(sa.client_email)
        .setAudience(TOKEN_URL)
        .setIssuedAt(now)
        .setExpirationTime(now + 3600)
        .sign(key);

    const res = await fetch(TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion: jwt,
        }),
    });
    if (!res.ok) {
        const t = await res.text();
        throw new Error(`OAuth token exchange failed: ${res.status} ${t}`);
    }
    const data = await res.json();
    _cachedToken = {
        value: data.access_token,
        expiresAt: now + (data.expires_in ?? 3600),
    };
    return data.access_token;
}

function unauthorized(msg = "unauthorized"): Response {
    return new Response(msg, { status: 401 });
}

function json(body: unknown, status = 200): Response {
    return new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
    });
}

// Best-effort: record an edge-function crash into public.error_logs so it
// shows up in the admin System Health card alongside front-end errors.
// (see supabase/migration-2026-error-logs.sql). Never throws.
async function logEdgeError(fn: string, message: string, context: Record<string, unknown> = {}) {
    try {
        const url = Deno.env.get("SUPABASE_URL");
        const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (!url || !key) return;
        const sb = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
        await sb.from("error_logs").insert({
            source: "edge",
            message: String(message).slice(0, 1000),
            context: { fn, ...context },
        });
    } catch (_) { /* swallow, logging must never break the function */ }
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

    // 1. Verifye sekrè webhook la
    const expected = Deno.env.get("WEBHOOK_SECRET");
    if (expected) {
        const got = req.headers.get("x-webhook-secret")
            ?? req.headers.get("authorization")?.replace(/^Bearer\s+/i, "")
            ?? "";
        if (got !== expected) return unauthorized();
    }

    // 2. Parse payload webhook a
    let payload: any;
    try { payload = await req.json(); }
    catch { return json({ ok: false, error: "invalid json" }, 400); }
    const record = payload?.record ?? payload;
    if (!record || !record.user_id) {
        return json({ ok: true, skipped: "no user_id in payload" });
    }

    // 3. Chaje service-account JSON
    const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!saRaw) return json({ ok: false, error: "FCM_SERVICE_ACCOUNT_JSON not set" }, 500);
    let sa: ServiceAccount;
    try { sa = JSON.parse(saRaw); }
    catch { return json({ ok: false, error: "invalid FCM_SERVICE_ACCOUNT_JSON" }, 500); }
    if (!sa.project_id || !sa.private_key || !sa.client_email) {
        return json({ ok: false, error: "service account missing fields" }, 500);
    }

    // 4. Chèche aparèy itilizatè a nan user_devices
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
        return json({ ok: false, error: "missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: devices, error: devErr } = await supabase
        .from("user_devices")
        .select("id, fcm_token")
        .eq("user_id", record.user_id);
    if (devErr) return json({ ok: false, error: devErr.message }, 500);
    if (!devices || devices.length === 0) {
        return json({ ok: true, devices: 0, message: "no registered devices" });
    }

    // 5. Pran token OAuth (cache)
    let accessToken: string;
    try { accessToken = await getAccessToken(sa); }
    catch (e) { return json({ ok: false, error: String((e as Error).message) }, 500); }

    // 6. Voye push pou chak aparèy
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const title = String(record.title ?? "Ekomat");
    const body = String(record.body ?? "");
    const data: Record<string, string> = {
        type: String(record.type ?? ""),
        notif_id: String(record.id ?? ""),
        icon: String(record.icon ?? ""),
        url: "/",
    };

    const results: Array<Record<string, unknown>> = [];
    for (const dev of devices) {
        const message = {
            message: {
                token: dev.fcm_token,
                notification: { title, body },
                data,
                webpush: {
                    fcm_options: { link: "/" },
                    notification: {
                        icon: "/icon-192.png",
                        badge: "/icon-192.png",
                    },
                },
            },
        };
        let status = 0;
        let ok = false;
        let errBody: string | null = null;
        try {
            const r = await fetch(url, {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify(message),
            });
            status = r.status;
            ok = r.ok;
            if (!ok) {
                errBody = await r.text();
                // Token mò → efase l pou nou pa eseye ankò.
                if (status === 404
                    || (status === 400 && /INVALID_ARGUMENT|registration/i.test(errBody))) {
                    await supabase.from("user_devices").delete().eq("id", dev.id);
                }
            }
        } catch (e) {
            errBody = String((e as Error).message);
        }
        results.push({
            token: String(dev.fcm_token).slice(0, 12) + "…",
            status, ok, error: errBody,
        });
    }

    return json({ ok: true, sent: results.length, results });
  } catch (e) {
    await logEdgeError("send-push", (e as Error)?.message || String(e),
        { stack: (e as Error)?.stack ? String((e as Error).stack).slice(0, 1000) : null });
    return json({ ok: false, error: (e as Error)?.message || "unhandled" }, 500);
  }
});
