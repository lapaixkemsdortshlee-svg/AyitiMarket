// Jeneratè paj datterisaj (landing pages) Kreyòl pou SEO : Ekomat.
//
// Pouki: index.html se yon SPA yon sèl fichye ki pa gen kontni endèksab pou
// chak kategori/vil. Paj estatik sa yo bay Google (ak asistan AI) kontni
// reyèl an Kreyòl, ak lyen ki mennen nan app la. Yo se fichye estatik -
// Vercel sèvi yo anvan rewrite catch-all la (menm jan ak onboarding.html).
//
// Kouri: node scripts/gen-landing.mjs
// Sa a ekri: l/<slug>.html (paj yo) + sitemap.xml (rasin).
//
// Pou ajoute yon paj: mete yon antre nan PAGES epi re-kouri. Kontni an dwe
// INIK pou chak paj (evite kontni fen/duplike ki fè mal ak SEO).

import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const ORIGIN = 'https://ayiti-market.vercel.app';
const TODAY = new Date().toISOString().slice(0, 10);

// Vil Ekomat sèvi (soti nan seleksyon lokalizasyon app la).
const CITIES = ['Pòtoprens', 'Pétion-Ville', 'Delmas', 'Tabarre', 'Carrefour',
    'Kwadèbouke', 'Cap-Haïtien', 'Les Cayes'];

// ── Definisyon paj yo (kontni inik pou chak) ───────────────────────
const PAGES = [
    {
        slug: 'elektwonik',
        kind: 'kategori',
        h1: 'Achte Elektwonik an Ayiti',
        title: 'Achte Elektwonik an Ayiti : Telefòn, Akseswa | Ekomat',
        desc: 'Achte telefòn, aparèy elektwonik ak akseswa an Ayiti sou Ekomat. '
            + 'Peman MonCash pwoteje ak eskwo, vandè verifye, livrezon lokal.',
        intro: 'Ap chèche yon telefòn Digicel oswa Natcom, yon chajè, yon oto-radio '
            + 'oswa yon aparèy elektwonik an Ayiti? Sou Ekomat ou jwenn machandiz '
            + 'nan men vandè verifye, epi lajan ou rete pwoteje ak eskwo jiskaske ou '
            + 'resevwa pwodwi a nan men. Pa gen okenn risk pou fwod.',
        points: [
            ['Vandè verifye', 'Chak vandè soumèt ID + selfie, admin verifye yo anvan yo vann.'],
            ['Eskwo sou MonCash', 'Lajan w bloke jiskaske ou konfime resepsyon ak yon kòd OTP.'],
            ['Kominikasyon dirèk', 'Chat ak nòt vokal ak vandè a anvan ou achte.'],
        ],
        keywords: 'telefòn ayiti, elektwonik ayiti, achte telefòn moncash, natcom digicel',
    },
    {
        slug: 'mod',
        kind: 'kategori',
        h1: 'Achte Rad ak Mòd an Ayiti',
        title: 'Rad ak Mòd an Ayiti : Achte an liy | Ekomat',
        desc: 'Achte rad, soulye ak atik mòd an Ayiti sou Ekomat. Vandè verifye, '
            + 'peman MonCash ak eskwo, livrezon nan zòn ou.',
        intro: 'Rad fanm, rad gason, soulye, sak, dekouvri dènye mòd la nan men '
            + 'vandè ayisyen verifye. Sou Ekomat ou pale dirèk ak vandè a, ou wè '
            + 'foto reyèl pwodwi a, epi ou peye ak eskwo ki pwoteje lajan w jiskaske '
            + 'komann ou rive.',
        points: [
            ['Foto reyèl', 'Vandè yo mete plizyè foto, ou wè kondisyon reyèl atik la.'],
            ['Eskwo sou MonCash', 'Lajan w pa lage bay vandè a anvan ou resevwa komann ou.'],
            ['Livrezon lokal', 'Chwazi yon pwen kolèk tou pre w oswa fè livrezon.'],
        ],
        keywords: 'rad ayiti, mòd ayiti, soulye ayiti, achte rad an liy ayiti',
    },
    {
        slug: 'bote',
        kind: 'kategori',
        h1: 'Pwodwi Bote ak Kosmetik an Ayiti',
        title: 'Bote & Kosmetik an Ayiti : Achte an liy | Ekomat',
        desc: 'Achte pwodwi bote, swen po ak kosmetik an Ayiti sou Ekomat. '
            + 'Vandè verifye, peman MonCash pwoteje ak eskwo.',
        intro: 'Swen po, makiyaj, pafen, pwodwi cheve, jwenn pwodwi bote ki '
            + 'otantik nan men vandè verifye an Ayiti. Ekomat pwoteje chak '
            + 'acha ak eskwo: ou konfime ou resevwa pwodwi a anvan lajan an libere.',
        points: [
            ['Pwodwi otantik', 'Vandè verifye ak sistèm avi pou ou achte an konfyans.'],
            ['Eskwo sou MonCash', 'Pa gen pèt: lajan w rete bloke jiskaske livrezon fèt.'],
            ['Konsèy dirèk', 'Poze vandè a kesyon nan chat anvan ou deside.'],
        ],
        keywords: 'kosmetik ayiti, pwodwi bote ayiti, swen po ayiti, makiyaj ayiti',
    },
    {
        slug: 'atizana',
        kind: 'kategori',
        h1: 'Atizana Ayisyen : Achte Dirèk nan men Atizan yo',
        title: 'Atizana Ayisyen an Ayiti : Achte an liy | Ekomat',
        desc: 'Achte atizana ayisyen, travay bwa, fè, tablo, dekorasyon, dirèk nan '
            + 'men atizan verifye. Peman MonCash pwoteje ak eskwo sou Ekomat.',
        intro: 'Sipòte atizan ayisyen yo dirèkteman. Tablo, travay an fè dekoupe, '
            + 'objè an bwa, dekorasyon fèt men, achte atizana otantik sou Ekomat '
            + 'ak konfyans, paske eskwo a pwoteje lajan w jiskaske ou resevwa zèv la.',
        points: [
            ['Dirèk nan men atizan', 'San entèmedyè, pi bon pri pou ou, plis pou atizan an.'],
            ['Eskwo sou MonCash', 'Lajan w pwoteje jiskaske ou resevwa epi konfime.'],
            ['Livrezon nan tout peyi a', 'Soti Pòtoprens rive Okap, chwazi jan livrezon w.'],
        ],
        keywords: 'atizana ayisyen, atizana ayiti, travay fè ayiti, tablo ayisyen',
    },
    {
        slug: 'potoprens',
        kind: 'vil',
        h1: 'Ekomat nan Pòtoprens',
        title: 'Achte & Vann an liy nan Pòtoprens | Ekomat',
        desc: 'Achte ak vann an liy nan Pòtoprens ak zòn metwopolitèn nan '
            + '(Pétion-Ville, Delmas, Tabarre, Carrefour). Eskwo MonCash, vandè verifye.',
        intro: 'Nan Pòtoprens ak tout zòn metwopolitèn nan : Pétion-Ville, Delmas, '
            + 'Tabarre, Carrefour, Kwadèbouke : Ekomat konekte achtè ak vandè '
            + 'verifye. Chwazi yon pwen kolèk tou pre w, pale ak vandè a nan chat, '
            + 'epi peye ak eskwo ki pwoteje lajan w.',
        points: [
            ['Pwen kolèk pre w', 'GPS klase pwen kolèk yo pa distans, pi pre a an premye.'],
            ['Eskwo sou MonCash', 'Lajan w bloke jiskaske ou konfime resepsyon ak OTP.'],
            ['Vandè verifye', 'Achte ak konfyans nan men vandè ki pase verifikasyon.'],
        ],
        keywords: 'achte an liy pòtoprens, vann pòtoprens, marketplace ayiti, moncash pòtoprens',
    },
    {
        slug: 'kap-ayisyen',
        kind: 'vil',
        h1: 'Ekomat nan Cap-Haïtien (Okap)',
        title: 'Achte & Vann an liy nan Cap-Haïtien | Ekomat',
        desc: 'Achte ak vann an liy nan Cap-Haïtien (Okap) sou Ekomat. '
            + 'Eskwo MonCash ki pwoteje lajan w, vandè verifye, livrezon lokal.',
        intro: 'Nan Cap-Haïtien (Okap) ak nò peyi a, Ekomat pèmèt ou achte ak '
            + 'vann an tout sekirite. Jwenn machandiz nan men vandè verifye, kominike '
            + 'dirèkteman, epi kite eskwo a pwoteje lajan w jiskaske livrezon konfime.',
        points: [
            ['Mache lokal Okap', 'Konekte ak achtè ak vandè nan zòn nò a.'],
            ['Eskwo sou MonCash', 'Zewo risk fwod: lajan libere sèlman apre konfimasyon.'],
            ['Chat ak nòt vokal', 'Antann ou ak vandè a anvan ou deplase.'],
        ],
        keywords: 'achte an liy okap, cap-haïtien marketplace, vann okap, moncash okap',
    },
];

const OTHER = (cur) => PAGES.filter(p => p.slug !== cur.slug);

function page(p) {
    const url = `${ORIGIN}/l/${p.slug}.html`;
    const jsonld = {
        '@context': 'https://schema.org',
        '@graph': [
            {
                '@type': 'BreadcrumbList',
                itemListElement: [
                    { '@type': 'ListItem', position: 1, name: 'Ekomat', item: ORIGIN + '/' },
                    { '@type': 'ListItem', position: 2, name: p.h1, item: url },
                ],
            },
            {
                '@type': 'CollectionPage',
                name: p.h1,
                description: p.desc,
                url,
                inLanguage: 'ht',
                isPartOf: { '@type': 'WebSite', name: 'Ekomat', url: ORIGIN + '/' },
                about: { '@type': 'Organization', name: 'Ekomat', url: ORIGIN + '/' },
            },
        ],
    };
    const pts = p.points.map(([t, d]) => `
        <div class="card">
          <h3>${t}</h3>
          <p>${d}</p>
        </div>`).join('');
    const links = OTHER(p).map(o =>
        `<a href="/l/${o.slug}.html">${o.h1}</a>`).join('');
    return `<!DOCTYPE html>
<html lang="ht">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${p.title}</title>
<meta name="description" content="${p.desc}"/>
<meta name="keywords" content="${p.keywords}"/>
<link rel="canonical" href="${url}"/>
<meta property="og:type" content="website"/>
<meta property="og:site_name" content="Ekomat"/>
<meta property="og:title" content="${p.title}"/>
<meta property="og:description" content="${p.desc}"/>
<meta property="og:url" content="${url}"/>
<meta property="og:image" content="${ORIGIN}/og-image.png"/>
<meta property="og:image:width" content="1200"/>
<meta property="og:image:height" content="630"/>
<meta property="og:locale" content="ht_HT"/>
<meta name="twitter:card" content="summary_large_image"/>
<meta name="twitter:title" content="${p.title}"/>
<meta name="twitter:description" content="${p.desc}"/>
<meta name="twitter:image" content="${ORIGIN}/og-image.png"/>
<link rel="apple-touch-icon" href="/icon-192.png"/>
<link rel="manifest" href="/manifest.json"/>
<meta name="theme-color" content="#00666f"/>
<link rel="icon" type="image/png" sizes="64x64" href="/favicon.png"/>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@600;700;800&family=Manrope:wght@400;500;600&display=swap" rel="stylesheet"/>
<script type="application/ld+json">${JSON.stringify(jsonld)}</script>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:'Manrope',system-ui,sans-serif;color:#1c1c19;background:#fcf9f4;line-height:1.6}
  a{color:#00666f}
  .wrap{max-width:900px;margin:0 auto;padding:0 20px}
  header{padding:20px 0;border-bottom:1px solid #ece8e1}
  .brand{display:flex;align-items:center;gap:12px;text-decoration:none}
  .logo{width:40px;height:40px;border-radius:11px;background:#97422b;display:flex;align-items:center;justify-content:center;color:#fff;font-family:'Plus Jakarta Sans';font-weight:800;font-size:22px}
  .brand b{font-family:'Plus Jakarta Sans';font-weight:800;font-size:20px;color:#97422b}
  .brand b span{color:#00666f}
  .hero{padding:56px 0 40px;background:linear-gradient(135deg,#00666f,#004f57);color:#fcf9f4;text-align:center}
  .hero h1{font-family:'Plus Jakarta Sans';font-weight:800;font-size:2.1rem;letter-spacing:-.02em;line-height:1.15}
  .hero p{margin:16px auto 0;max-width:640px;color:rgba(255,255,255,.85)}
  .cta{display:inline-flex;align-items:center;gap:8px;margin-top:26px;background:#fcf9f4;color:#00666f;font-family:'Plus Jakarta Sans';font-weight:800;text-decoration:none;padding:14px 28px;border-radius:50px;box-shadow:0 10px 28px rgba(0,0,0,.24)}
  section{padding:38px 0}
  h2{font-family:'Plus Jakarta Sans';font-weight:800;font-size:1.4rem;margin-bottom:18px;letter-spacing:-.01em}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}
  .card{background:#fff;border:1px solid #ece8e1;border-radius:16px;padding:20px}
  .card h3{font-family:'Plus Jakarta Sans';font-weight:700;font-size:1.05rem;color:#00666f;margin-bottom:6px}
  .chips{display:flex;flex-wrap:wrap;gap:8px}
  .chip{background:#fff;border:1px solid #ddd7cd;border-radius:999px;padding:7px 15px;font-size:.9rem;font-weight:600}
  .links{display:flex;flex-wrap:wrap;gap:14px}
  footer{border-top:1px solid #ece8e1;padding:28px 0;color:#7e7e76;font-size:.9rem}
</style>
</head>
<body>
<header><div class="wrap"><a class="brand" href="/"><img src="/brand/logo-ekomat.png" alt="Ekomat" height="34" style="display:block;height:34px;width:auto"/></a></div></header>

<div class="hero"><div class="wrap">
  <h1>${p.h1}</h1>
  <p>${p.intro}</p>
  <a class="cta" href="/">Louvri Ekomat →</a>
</div></div>

<div class="wrap">
  <section>
    <h2>Poukisa Ekomat</h2>
    <div class="grid">${pts}</div>
  </section>

  <section>
    <h2>${p.kind === 'vil' ? 'Kategori ki disponib' : 'Vil nou sèvi'}</h2>
    <div class="chips">
      ${(p.kind === 'vil'
          ? ['Elektwonik', 'Mòd', 'Bote & Kosmetik', 'Gaming', 'Akseswa', 'Atizana', 'Kay', 'Bebe']
          : CITIES).map(x => `<span class="chip">${x}</span>`).join('\n      ')}
    </div>
  </section>

  <section>
    <h2>Kijan sa mache</h2>
    <div class="grid">
      <div class="card"><h3>1. Chwazi</h3><p>Jwenn pwodwi a epi pale ak vandè verifye a nan chat.</p></div>
      <div class="card"><h3>2. Peye ak eskwo</h3><p>Voye peman MonCash, lajan w rete bloke, an sekirite.</p></div>
      <div class="card"><h3>3. Konfime</h3><p>Resevwa komann ou, bay kòd OTP a, epi lajan libere.</p></div>
    </div>
  </section>

  <section>
    <h2>Dekouvri plis</h2>
    <div class="links">${links} <a href="/">Paj dakèy</a></div>
  </section>
</div>

<footer><div class="wrap">
  Ekomat : Marketplace mobil Ayisyen an. Achte ak vann an tout sekirite ak eskwo. ·
  <a href="/">Louvri app la</a>
</div></footer>
</body>
</html>
`;
}

// ── Ekri paj yo ────────────────────────────────────────────────────
mkdirSync(join(ROOT, 'l'), { recursive: true });
for (const p of PAGES) {
    writeFileSync(join(ROOT, 'l', `${p.slug}.html`), page(p));
}

// ── Ekri sitemap.xml ───────────────────────────────────────────────
const urls = [
    { loc: ORIGIN + '/', priority: '1.0' },
    { loc: ORIGIN + '/onboarding.html', priority: '0.5' },
    ...PAGES.map(p => ({ loc: `${ORIGIN}/l/${p.slug}.html`, priority: '0.8' })),
];
const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(u => `  <url>
    <loc>${u.loc}</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>${u.priority}</priority>
  </url>`).join('\n')}
</urlset>
`;
writeFileSync(join(ROOT, 'sitemap.xml'), sitemap);

console.log(`Generated ${PAGES.length} landing pages + sitemap.xml (${urls.length} urls).`);
