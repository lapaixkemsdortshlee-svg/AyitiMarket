# send-email : Supabase Edge Function

Voye yon imèl tranzaksyonèl bay yon itilizatè chak fwa yon ranje kreye
nan tab `public.notifications`. Sèvi ak [Resend](https://resend.com) -
plan gratis bay 100 imèl/jou.

## 1. Kreye yon kont Resend + verifye domèn ou

1. Ale sou [resend.com](https://resend.com) → enskri (gratis)
2. **Domains** → **Add Domain** → tape domèn ou (egz. domèn Ekomat ou pral achte a)
3. Resend ap ba ou kèk DNS records pou ajoute sou pwovayè domèn ou
   (Vercel, Cloudflare, etc.). Yo dwe verifye anvan w ka voye.
4. **API Keys** → **Create API Key** → kopye kle a (`re_xxx`)

## 2. Konfigire sekrè Supabase yo (atravè Studio)

Supabase Studio → **Project Settings → Edge Functions → Secrets**:

| Name | Value |
|---|---|
| `RESEND_API_KEY` | `re_xxx` (sòti nan etap 1) |
| `EMAIL_FROM` | `Ekomat <noreply@ekomat.example>` (domèn dwe verifye) |
| `WEBHOOK_SECRET` | **menm valè** ak send-push la (oswa nouvo si w prefere) |

## 3. Deplwaye fonksyon an

Atravè Studio:
1. Edge Functions → **Deploy a new function**
2. Name: `send-email`
3. Kopye kontni `index.ts` la → kole
4. Dekoche **Verify JWT**
5. Klike **Deploy**

Oswa via CLI:
```bash
supabase functions deploy send-email --no-verify-jwt
```

## 4. Konfigire Database Webhook la

Supabase Studio → **Database → Webhooks → Create**:

| Chan | Valè |
|---|---|
| Name | `notifications-email` |
| Table | `notifications` |
| Events | ✅ Insert |
| URL | `https://<projet>.supabase.co/functions/v1/send-email` |
| Header `x-webhook-secret` | menm valè ak sekrè a |

> Ou ka gen 2 webhooks sou menm tab la, youn pou push, youn pou imèl.

## 5. Teste

```sql
insert into public.notifications (user_id, type, icon, title, body, color)
values (auth.uid(), 'system', 'verified', 'Tès imèl', 'Si w resevwa imèl sa a, tout bagay mache!', '#1e40af');
```

Tcheke bwat resepsyon imèl ou. Si pa gen anyen:
```bash
supabase functions logs send-email --tail
```

## Eta gracieux

Si `RESEND_API_KEY` oswa `EMAIL_FROM` pa mete, fonksyon an retounen
`{ ok: true, skipped: "..." }`, okenn erè 5xx, okenn blokay pou flow
notifikasyon an. Ou ka deplwaye fonksyon an depi kounye a san konfigire
Resend, epi konplete sa pi devan.

## Sekirite

- `RESEND_API_KEY` pa gen pou prezan kòd kliyan an, sove l sèlman kòm
  Supabase secret.
- `WEBHOOK_SECRET` pwoteje fonksyon an kont apèl piblik.
