// supabase/functions/send-pending-emails/index.ts
//
// Drains the public.pending_emails outbox and sends each row through
// Resend. Designed to be invoked on a schedule (pg_cron via the
// supabase_functions extension, or any external scheduler that
// hits this function's URL with the anon key).
//
// Required secrets (set via `supabase secrets set ...`):
//   RESEND_API_KEY   — your Resend API key (re_...)
//   RESEND_FROM      — optional, sender address. Defaults to a
//                      Resend-provided sandbox address. Use a verified
//                      domain in production (e.g.
//                      "AyitiMarket <noreply@ayitimarket.com>").
//
// Provided automatically by the Edge Functions runtime:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY  — bypasses RLS so we can read/write the
//                                outbox even though the table is
//                                admin-only at the policy layer.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

interface PendingEmail {
  id: string;
  to_user: string;
  subject: string;
  body: string;
}

interface ProcessResult {
  ok: boolean;
  processed: number;
  sent: number;
  errored: number;
  ms: number;
  error?: string;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const RESEND_KEY   = Deno.env.get("RESEND_API_KEY");
const RESEND_FROM  = Deno.env.get("RESEND_FROM") ?? "AyitiMarket <onboarding@resend.dev>";
const BATCH_LIMIT  = 50;

if (!SUPABASE_URL || !SERVICE_KEY) {
  throw new Error("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY");
}
if (!RESEND_KEY) {
  throw new Error("Missing RESEND_API_KEY — set it with `supabase secrets set RESEND_API_KEY=...`");
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

/**
 * Resolve the recipient's actual email. profiles.email is best-effort
 * (depends on what the seller put in their profile); auth.users.email
 * is authoritative because it's whatever they signed in with.
 */
async function resolveEmail(userId: string): Promise<string> {
  const { data, error } = await supabase.auth.admin.getUserById(userId);
  if (error) throw new Error(`auth lookup failed: ${error.message}`);
  const email = data?.user?.email;
  if (!email) throw new Error("user has no email on file");
  return email;
}

async function sendViaResend(to: string, subject: string, body: string): Promise<void> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM,
      to: [to],
      subject,
      text: body,
    }),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new Error(`Resend ${res.status}: ${detail || res.statusText}`);
  }
}

async function markSent(id: string): Promise<void> {
  const { error } = await supabase
    .from("pending_emails")
    .update({
      status: "sent",
      sent_at: new Date().toISOString(),
      error: null,
    })
    .eq("id", id);
  if (error) console.error(`[send] mark-sent failed for ${id}:`, error.message);
}

async function markError(id: string, message: string): Promise<void> {
  const { error } = await supabase
    .from("pending_emails")
    .update({
      status: "error",
      error: message.slice(0, 500),
    })
    .eq("id", id);
  if (error) console.error(`[send] mark-error failed for ${id}:`, error.message);
}

async function processBatch(): Promise<ProcessResult> {
  const startedAt = Date.now();

  const { data: rows, error: selErr } = await supabase
    .from("pending_emails")
    .select("id, to_user, subject, body")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(BATCH_LIMIT);

  if (selErr) {
    return { ok: false, processed: 0, sent: 0, errored: 0, ms: Date.now() - startedAt, error: selErr.message };
  }

  const queue = (rows ?? []) as PendingEmail[];
  let sent = 0;
  let errored = 0;

  for (const row of queue) {
    try {
      const to = await resolveEmail(row.to_user);
      await sendViaResend(to, row.subject, row.body);
      await markSent(row.id);
      sent++;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`[send] row ${row.id} failed:`, msg);
      await markError(row.id, msg);
      errored++;
    }
  }

  return { ok: true, processed: queue.length, sent, errored, ms: Date.now() - startedAt };
}

Deno.serve(async (req) => {
  // Reject anything other than POST/GET so this endpoint can't be
  // walked through arbitrary HTTP verbs.
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const result = await processBatch();
    return new Response(JSON.stringify(result), {
      status: result.ok ? 200 : 500,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[send] fatal:", msg);
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
