# send-push : Supabase Edge Function

Voye yon vrè notifikasyon push FCM HTTP v1 bay tout aparèy yon itilizatè
chak fwa yon ranje kreye nan tab `public.notifications`.

## 1. Jenere Firebase Service Account JSON

1. [Firebase Console](https://console.firebase.google.com) → pwojè
   **ayitimarket-19c78** → ⚙️ **Project settings** → onglè **Service
   accounts**
2. Klike **« Generate new private key »** → konfime → yon fichye `.json`
   ap telechaje
3. Louvri fichye a, w ap wè yon objè JSON ki gen `project_id`,
   `private_key`, `client_email`, etc. **Pa pataje l ak pèsòn**.

## 2. Konfigire sekrè Supabase yo

```bash
# Kontni JSON la nèt, kenbe ladan li nan yon sèl liy oswa itilize
# --env-file. Anba a se opsyon ki pi senp lan:
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat /chemen/firebase-adminsdk.json)"

# Yon sekrè ou jenere ou menm, pou pwoteje fonksyon an kont apèl piblik
supabase secrets set WEBHOOK_SECRET="$(openssl rand -hex 32)"
```

> Si w pa enstale Supabase CLI, ou ka mete yo nan Supabase Studio →
> **Project Settings** → **Edge Functions** → **Add new secret**.

## 3. Deplwaye fonksyon an

```bash
supabase functions deploy send-push --no-verify-jwt
```

`--no-verify-jwt` enpòtan: Database Webhooks Supabase pa voye yon JWT
itilizatè, nou itilize `WEBHOOK_SECRET` la pito.

## 4. Konfigire Database Webhook la

1. Supabase Studio → **Database** → **Webhooks** → **Create a new hook**
2. **Name**: `notifications-push`
3. **Table**: `notifications`
4. **Events**: ✅ Insert (sèl la, pa Update/Delete)
5. **Type**: HTTP Request
6. **HTTP Method**: POST
7. **URL**:
   `https://<project-ref>.supabase.co/functions/v1/send-push`
   (chèche `<project-ref>` ou nan Settings → API)
8. **HTTP Headers**, ajoute:
   - `x-webhook-secret`: valè ou te mete nan WEBHOOK_SECRET la
   - `Content-Type`: `application/json` (deja la default)
9. **Save**

## 5. Teste

1. Sou app la, fè yon aksyon ki ekri yon notifikasyon (kòmand,
   konfimasyon, etc.) bay yon itilizatè ki gen yon `user_devices` ranje
2. Itilizatè a dwe wè yon push (foreground = toast in-app; background =
   notifikasyon OS)
3. Si pa gen anyen, gade log fonksyon an:
   ```bash
   supabase functions logs send-push
   ```

## 6. Sa fonksyon an retounen

```json
{ "ok": true, "sent": 2, "results": [
  { "token": "fEz4P9aBcD…", "status": 200, "ok": true, "error": null },
  { "token": "cUQbXmKi__…", "status": 404, "ok": false, "error": "…UNREGISTERED…" }
]}
```

Token ki retounen `404 UNREGISTERED` oswa `400 INVALID_ARGUMENT`
otomatikman efase nan `user_devices`, w pa bezwen netwaye.

## Sekirite

- `FCM_SERVICE_ACCOUNT_JSON` se yon **kle privè**, pa janm commit li
  oswa pataje l. Si li lèk, revoke kle a nan Firebase Console epi
  jenere yon nouvo.
- `WEBHOOK_SECRET` se yon dezyèm baryè, chanje l si w sispèk yon lèk.
- `--no-verify-jwt` vle di nenpòt moun ka frape URL fonksyon an;
  `WEBHOOK_SECRET` la se sa ki pwoteje l.
