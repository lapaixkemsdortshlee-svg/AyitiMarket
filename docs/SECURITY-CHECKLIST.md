# Chèkliz sekirite, sa ou bezwen klike nan UI

PR sa a deplwaye tout sa ki ka fèt nan kòd la (CSP, HSTS, CodeQL,
Dependabot, axe tests, SECURITY.md). Sa ki rete egzije aksyon
manyèl nan dashboards. Suiv lis sa a nan lòd.

## 1. GitHub : Repository Settings

### A. Mete repo a prive
**GitHub** → repo `AyitiMarket` → **Settings** → **General** →
desann tout an ba → **Danger Zone** → **Change repository visibility**
→ **Make private** → konfime non repo a.

> ⚠️ **Atansyon Vercel**: Free plan an mande repo piblik pou
> deplwaman otomatik. Si ou move sou prive, ou ka oblije:
>   - Upgrade Vercel sou **Pro** (~$20/mwa), oswa
>   - Konekte Vercel ak yon Personal Access Token GitHub
>
> Si Vercel sispann deplwaye, retounen vizib piblik tanporèman epi
> kontakte sipò Vercel.

### B. Branch Protection sou `main`
**Settings → Branches → Add branch protection rule**:
- Branch name pattern: `main`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Add `smoke` (Playwright)
  - Add `Analyze JavaScript / TypeScript` (CodeQL)
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

### C. Security & Analysis
**Settings → Code security and analysis**:
- ✅ **Dependabot alerts** → Enable
- ✅ **Dependabot security updates** → Enable
- ✅ **Secret scanning** → Enable
- ✅ **Push protection** → Enable (bloke push ki gen sekrè ladann)
- ✅ **Code scanning** → CodeQL deja konfigire via workflow

### D. Collaborateurs
**Settings → Collaborators and teams**:
- Retire nenpòt moun ki pa bezwen aksè
- Mete 2FA obligatwa sou ou ak nenpòt admin

## 2. Vercel

### A. Aktive 2FA sou kont Vercel
**vercel.com → Account Settings → Security → Two-Factor Auth**

### B. Env vars verifye
**Project Settings → Environment Variables**, tcheke ke `SUPABASE_URL`,
`SUPABASE_ANON_KEY` (oswa lòt yo si w ajoute) byen sove.

### C. Domèn ou : HSTS preload
Apre HSTS aktif yon mwa, soumèt sou
[hstspreload.org](https://hstspreload.org/) pou ajoute domèn ou
nan lis preload navigatè yo.

## 3. Supabase

### A. Aktive MFA sou kont ou
**Account → Security → Two-Factor Authentication**

### B. Revize RLS sou tab kliyan yo
**SQL Editor**, kouri:
```sql
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname='public' and tablename in (
  'profiles','products','orders','cart_items','messages',
  'notifications','user_devices','user_addresses','promo_codes',
  'promo_redemptions','reviews','favorites','followers',
  'verification_requests','flash_deals','app_settings'
);
```
Tout dwe gen `rowsecurity = true`. Si non, gade `supabase/rls-policies.sql`.

### C. Revoke kle ki konpwomèt
Si w sispèk yon kle (anon oswa service_role) lèk:
**Project Settings → API → Reset keys** → mete ajou Vercel + Edge
Function secrets.

### D. Edge Function secrets
Tcheke ke `FCM_SERVICE_ACCOUNT_JSON`, `RESEND_API_KEY`, `WEBHOOK_SECRET`
yo sèlman mete kòm sekrè (pa nan kòd). Komand:
```bash
supabase secrets list
```

## 4. Firebase

### A. MFA sou Google Account ou
**myaccount.google.com → Security → 2-Step Verification**

### B. Restriksyon `apiKey`
**Firebase Console → Project Settings → Cloud Messaging** → vle wè
domèn ki otorize. Si w pa fè l deja:
**Google Cloud Console → APIs & Services → Credentials** → kle Web
ou a → **Application restrictions** → HTTP referrers →
ajoute `https://*.vercel.app/*` ak vrè domèn ou.

### C. Rotation service-account
Si JSON service-account konpwomèt:
**Project Settings → Service accounts → Manage all service accounts**
→ kle ki konpwomèt la → **Delete** → jenere nouvo → mete ajou sekrè
Supabase.

## 5. Resend (lè ou pare)

### A. MFA sou kont Resend
**Settings → Security → 2FA**

### B. API keys
Sèlman jenere kle "sending" (pa kle admin) pou Edge Function. Si
yon kle konpwomèt, revoke l imedyatman.

## 6. MonCash / Digicel (priyorite #1, tann)

Lè ou ap konekte ak Digicel:
- Sèvi sèlman ak HTTPS
- Bearer token nan sekrè Supabase, pa nan kòd
- Tcheke siyatè webhook MonCash si li bay youn
- Logge tout tranzaksyon ak destinasyon + montan + ref

## 7. Wotasyon sekrè regilye

Chak 90 jou:
- Resèt anon key Supabase si pa gen klein evidans li lèk (opsyonèl)
- Resèt VAPID FCM
- Resèt `WEBHOOK_SECRET` Edge Function
- Resèt `RESEND_API_KEY`

Mete sa nan kalendriye ou.

## 8. Sa pou siveye chak semèn

- GitHub → **Security overview** : Dependabot/CodeQL alèt
- Supabase → **Logs & Analytics → Edge Functions**, gade fonksyon ki
  echwe / 429
- Vercel → **Deployments**, tcheke deplwaman ki fail
- Sentry oswa lòt zouti monitoring (TODO: ajoute youn)

## Si ou panse gen yon kontak

1. Chanje tout modpas Supabase + Firebase + Vercel
2. Resèt tout sekrè
3. Tcheke aktivite anormal nan log yo
4. Kontakte sipò pwovayè a
5. Notifye itilizatè yo si done potansyèlman ekspoze
