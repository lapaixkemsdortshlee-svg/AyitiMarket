// supabase/functions/send-email/index.ts
//
// Edge Function ki voye yon imèl tranzaksyonèl chak fwa yon ranje
// kreye nan tab `public.notifications`. Lè notif la se yon kòmand
// (gen `data.order_id`), nou chèche kòmand la pou ranje yon imèl ki
// rich (pwodwi, total, zòn kolèk, OTP, etc.).
//
// SECRETS POU KONFIGIRE:
//   RESEND_API_KEY   →  re_xxx, soti nan resend.com
//   EMAIL_FROM       →  egz. "Ekomat <noreply@ekomat.example>"
//   WEBHOOK_SECRET   →  menm sekrè ki itilize ak send-push
//
// DEPLWAYE:
//   supabase functions deploy send-email --no-verify-jwt
//
// Eta gracieux: si Resend pa konfigire, fonksyon retounen
// { ok:true, skipped:"..." }, pa kraze flux la.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const RESEND_URL = "https://api.resend.com/emails";
const APP_URL = "https://ayiti-market.vercel.app/";

function unauthorized(): Response {
    return new Response("unauthorized", { status: 401 });
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

const fmtHTG = (n: unknown) => {
    const v = Number(n) || 0;
    return v.toLocaleString("fr-FR") + " HTG";
};

// Bati yon kad email konsistan (header koulè + kò + footer).
function shellHtml(opts: {
    color: string;
    eyebrow: string;
    title: string;
    bodyHtml: string;
}): string {
    return `<!DOCTYPE html>
<html lang="ht"><body style="margin:0;padding:0;background:#fcf9f4;font-family:'Helvetica Neue',Arial,sans-serif;color:#1c1c19">
  <div style="max-width:560px;margin:24px auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #e5e2dd">
    <div style="padding:24px;background:${opts.color}14;border-bottom:3px solid ${opts.color}">
      <p style="margin:0;font-size:11px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:${opts.color}">${opts.eyebrow}</p>
      <h1 style="margin:8px 0 0;font-size:20px;font-weight:800;color:#1c1c19">${opts.title}</h1>
    </div>
    <div style="padding:24px">
      ${opts.bodyHtml}
      <a href="${APP_URL}" style="display:inline-block;margin-top:20px;padding:12px 20px;border-radius:10px;background:${opts.color};color:#fff;text-decoration:none;font-weight:700;font-size:14px">
        Louvri Ekomat
      </a>
    </div>
    <div style="padding:14px 24px;background:#f6f3ee;border-top:1px solid #e5e2dd">
      <p style="margin:0;font-size:11px;color:#6d7979;line-height:1.5">
        Ou resevwa imèl sa a paske ou enskri sou Ekomat.
        Pou koupe imèl yo, ale nan Paramèt → Notifikasyon.
      </p>
    </div>
  </div>
</body></html>`;
}

// Kat enfòmasyon kòmand, itilize nan plizyè modèl.
function orderCardHtml(o: Record<string, any>, opts: { showOtp?: boolean } = {}): string {
    const otpRow = opts.showOtp && o.otp_code
        ? `<tr><td style="padding:6px 0;color:#6d7979;font-size:13px">Kòd OTP</td>
           <td style="padding:6px 0;text-align:right;font-size:18px;font-weight:800;letter-spacing:.3em;color:#00666f">${o.otp_code}</td></tr>`
        : "";
    return `<div style="margin:0 0 14px;padding:14px;border:1px solid #e5e2dd;border-radius:12px;background:#fafaf7">
  <p style="margin:0 0 8px;font-size:15px;font-weight:700">${o.product_title || "Pwodwi"}</p>
  <table style="width:100%;border-collapse:collapse;font-size:13px">
    <tr><td style="padding:4px 0;color:#6d7979">Kantite</td>
        <td style="padding:4px 0;text-align:right">${o.quantity || 1}</td></tr>
    <tr><td style="padding:4px 0;color:#6d7979">Total</td>
        <td style="padding:4px 0;text-align:right;font-weight:700">${fmtHTG(o.total_amount)}</td></tr>
    <tr><td style="padding:4px 0;color:#6d7979">Zòn kolèk</td>
        <td style="padding:4px 0;text-align:right">${o.pickup_location || "-"}</td></tr>
    <tr><td style="padding:4px 0;color:#6d7979">Vandè</td>
        <td style="padding:4px 0;text-align:right">${o.seller_name || "-"}</td></tr>
    <tr><td style="padding:4px 0;color:#6d7979">ID kòmand</td>
        <td style="padding:4px 0;text-align:right;font-family:monospace;font-size:11px">${String(o.id || "").slice(0, 8)}</td></tr>
    ${otpRow}
  </table>
</div>`;
}

// Chwazi modèl la dapre `data.kind`. Chak retounen { subject, html }.
function renderOrderTemplate(
    kind: string,
    order: Record<string, any>,
    record: Record<string, any>,
    recipientIsBuyer: boolean,
): { subject: string; html: string } {
    const product = order.product_title || "kòmand";
    const total = fmtHTG(order.total_amount);

    if (kind === "order_placed") {
        return {
            subject: `[Ekomat] Resi kòmand : ${product}`,
            html: shellHtml({
                color: "#97422b",
                eyebrow: "Resi kòmand",
                title: `Kòmand ou kreye : ${product}`,
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    Mèsi! Kòmand ou anrejistre. Voye <strong>${total}</strong> MonCash
                    bay Ekomat pou eskwo kòmanse. Apre admin verifye peman an,
                    vandè a ap prepare pwodwi a.
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "payment_verified") {
        return {
            subject: recipientIsBuyer
                ? `[Ekomat] Peman ou konfime : ${product}`
                : `[Ekomat] Peman kliyan an konfime : ${product}`,
            html: shellHtml({
                color: "#1e40af",
                eyebrow: "Eskwo aktive",
                title: recipientIsBuyer ? "Peman ou konfime" : "Peman kliyan an konfime",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    ${recipientIsBuyer
                        ? "Lajan ou bloke nan eskwo. Vandè a ap prepare pwodwi a."
                        : `Lajan pou <strong>${product}</strong> bloke nan eskwo. Prepare pwodwi a epi make li "pare pou kolèk".`}
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "ready_for_pickup") {
        return {
            subject: `[Ekomat] Pwodwi ou pare pou kolèk : ${product}`,
            html: shellHtml({
                color: "#00666f",
                eyebrow: "Pare pou kolèk",
                title: "Pwodwi ou pare!",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    <strong>${product}</strong> disponib nan
                    <strong>${order.pickup_location || "pwen kolèk la"}</strong>.
                    Pran kòd OTP ou anba a epi prezante l bay vandè a.
                </p>` + orderCardHtml(order, { showOtp: true }),
            }),
        };
    }
    if (kind === "otp_confirmed") {
        return {
            subject: `[Ekomat] Livrezon konfime : ${product}`,
            html: shellHtml({
                color: "#065f46",
                eyebrow: "Livrezon konfime",
                title: recipientIsBuyer ? "Mèsi pou konfyans ou!" : "Achtè a konfime resepsyon",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    ${recipientIsBuyer
                        ? "OTP ou valide ak siksè. Tranzaksyon an fini."
                        : `Achtè a konfime resepsyon <strong>${product}</strong>. Lajan ap libere talè.`}
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "released") {
        return {
            subject: recipientIsBuyer
                ? `[Ekomat] Tranzaksyon fèmen : ${product}`
                : `[Ekomat] Lajan libere : ${total}`,
            html: shellHtml({
                color: "#065f46",
                eyebrow: recipientIsBuyer ? "Tranzaksyon fèmen" : "Lajan libere",
                title: recipientIsBuyer ? "Mèsi!" : "Lajan voye sou MonCash ou",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    ${recipientIsBuyer
                        ? `Kòmand <strong>${product}</strong> fini. Mèsi pou itilize Ekomat!`
                        : `Admin lage <strong>${fmtHTG(order.net_amount || order.total_amount)}</strong> bay ou nan MonCash.`}
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "cancelled") {
        return {
            subject: `[Ekomat] Kòmand anile : ${product}`,
            html: shellHtml({
                color: "#991b1b",
                eyebrow: "Kòmand anile",
                title: "Kòmand sa a anile",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    Kòmand <strong>${product}</strong> anile.
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "refunded") {
        return {
            subject: `[Ekomat] Kòmand ranbouse : ${product}`,
            html: shellHtml({
                color: "#97422b",
                eyebrow: "Ranbouseman",
                title: "Kòmand ranbouse",
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    ${String(record.body || "Admin ranbouse kòmand sa a.")}
                </p>` + orderCardHtml(order),
            }),
        };
    }
    if (kind === "dispute") {
        return {
            subject: `[Ekomat] Litij ouvri : ${product}`,
            html: shellHtml({
                color: "#991b1b",
                eyebrow: "Litij",
                title: String(record.title || "Litij ouvri"),
                bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                    ${String(record.body || "Yon litij ouvri sou kòmand sa a. Admin ap egzamine.")}
                </p>` + orderCardHtml(order),
            }),
        };
    }
    // Fallback for any unknown order kind
    return {
        subject: `[Ekomat] ${record.title || product}`,
        html: shellHtml({
            color: String(record.color || "#00666f"),
            eyebrow: "Kòmand",
            title: String(record.title || product),
            bodyHtml: `<p style="margin:0 0 12px;font-size:15px;line-height:1.55">
                ${String(record.body || "")}
            </p>` + orderCardHtml(order),
        }),
    };
}

// Imèl jenerik lè notif la pa gen yon order_id (sistèm, chat, promo).
function renderGenericEmail(record: Record<string, any>): { subject: string; html: string } {
    const title = String(record.title || "Ekomat");
    const body = String(record.body || "Ou gen yon nouvèl notifikasyon nan Ekomat.");
    const color = String(record.color || "#00666f");
    const type = String(record.type || "system");
    const eyebrow: Record<string, string> = {
        order: "Kòmand", chat: "Mesaj", system: "Sistèm", promo: "Pwomosyon",
    };
    return {
        subject: `[Ekomat] ${title}`,
        html: shellHtml({
            color,
            eyebrow: eyebrow[type] || "Ekomat",
            title,
            bodyHtml: `<p style="margin:0;font-size:15px;line-height:1.55;color:#3d4949">${body}</p>`,
        }),
    };
}

Deno.serve(async (req: Request) => {
    if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

    const expected = Deno.env.get("WEBHOOK_SECRET");
    if (expected) {
        const got = req.headers.get("x-webhook-secret")
            ?? req.headers.get("authorization")?.replace(/^Bearer\s+/i, "")
            ?? "";
        if (got !== expected) return unauthorized();
    }

    let payload: any;
    try { payload = await req.json(); }
    catch { return json({ ok: false, error: "invalid json" }, 400); }
    const record = payload?.record ?? payload;
    if (!record || !record.user_id) {
        return json({ ok: true, skipped: "no user_id in payload" });
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("EMAIL_FROM");
    if (!apiKey || !from) {
        return json({ ok: true, skipped: "RESEND_API_KEY or EMAIL_FROM not configured" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
        return json({ ok: false, error: "missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, 500);
    }
    const supabase = createClient(supabaseUrl, serviceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
    });

    // Chèche imèl resipyan an
    let email: string | null = null;
    try {
        const { data, error } = await supabase.auth.admin.getUserById(record.user_id);
        if (error) console.warn("[send-email] getUserById:", error.message);
        else email = data?.user?.email ?? null;
    } catch (e) {
        console.warn("[send-email] getUserById threw:", (e as Error).message);
    }
    if (!email) return json({ ok: true, skipped: "recipient has no email" });

    // Bati imèl la, modèl rich si nou gen yon order_id
    let subject = "", html = "";
    const data = (record.data ?? {}) as Record<string, any>;
    const orderId = data.order_id;
    const kind = String(data.kind || "");

    if (orderId) {
        const { data: order, error: oErr } = await supabase
            .from("orders").select("*").eq("id", orderId).maybeSingle();
        if (oErr) console.warn("[send-email] order fetch:", oErr.message);
        if (order) {
            const recipientIsBuyer = order.buyer_id === record.user_id;
            ({ subject, html } = renderOrderTemplate(kind, order, record, recipientIsBuyer));
        }
    }
    if (!subject) ({ subject, html } = renderGenericEmail(record));

    try {
        const res = await fetch(RESEND_URL, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${apiKey}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ from, to: [email], subject, html }),
        });
        const status = res.status;
        const body = await res.text();
        if (!res.ok) return json({ ok: false, status, body }, 500);
        return json({ ok: true, status, kind, hasOrder: !!orderId, body: body ? JSON.parse(body) : null });
    } catch (e) {
        await logEdgeError("send-email", (e as Error)?.message || String(e),
            { stack: (e as Error)?.stack ? String((e as Error).stack).slice(0, 1000) : null });
        return json({ ok: false, error: (e as Error).message }, 500);
    }
});
