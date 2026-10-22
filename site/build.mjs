// Builds riffle.aignix.online into dist/. Run: node build.mjs
// Landing page = src/index.html, blog posts = src/blog/*.md (front matter + markdown).
// No dependencies except the vendored marked (the same copy the app bundles).
import { readFileSync, writeFileSync, mkdirSync, rmSync, cpSync, readdirSync, existsSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);
const { marked } = require("./vendor/marked.min.js");

const ROOT = path.dirname(new URL(import.meta.url).pathname);
const SRC = path.join(ROOT, "src");
const DIST = path.join(ROOT, "dist");

// ── The one place to change the domain, version or download link ──────────────
export const SITE = {
  url: "https://riffle.aignix.online",
  name: "Riffle",
  version: "1.0.1",
  dmgSize: "2.1 MB",
  minOS: "macOS 14 Sonoma or later",
  download: "https://github.com/princeyadav841426/Riffle/releases/latest/download/Riffle.dmg",
  repo: "https://github.com/princeyadav841426/Riffle",
  releases: "https://github.com/princeyadav841426/Riffle/releases",
  maker: { name: "Aignix", url: "https://aignix.online" },
  published: "2026-10-22",
};

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const icon = {
  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>',
  github: '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.53-1.33-1.28-1.69-1.28-1.69-1.05-.72.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.73-1.55-2.56-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.29 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.8 1.19 1.83 1.19 3.09 0 4.42-2.69 5.39-5.25 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5Z"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12.5 4.5 4.5L19 7"/></svg>',
};

const fill = (html) =>
  html
    .replaceAll("{{download}}", SITE.download)
    .replaceAll("{{repo}}", SITE.repo)
    .replaceAll("{{releases}}", SITE.releases)
    .replaceAll("{{version}}", SITE.version)
    .replaceAll("{{dmgSize}}", SITE.dmgSize)
    .replaceAll("{{minOS}}", SITE.minOS)
    .replaceAll("{{maker}}", SITE.maker.url)
    .replace(/\{\{icon:(\w+)\}\}/g, (_, name) => icon[name] ?? "");

const nav = [
  ["/#features", "Features"],
  ["/#install", "Install"],
  ["/#compare", "Compare"],
  ["/blog", "Blog"],
  ["/#faq", "FAQ"],
];

function head({ title, description, canonical, type = "website", image = "/og.jpg", jsonld = [], extra = "" }) {
  const url = SITE.url + canonical;
  const img = SITE.url + image;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${url}">
<meta name="robots" content="index, follow, max-image-preview:large">
<meta name="theme-color" content="#f6f6f6">
<meta name="color-scheme" content="light">
<meta property="og:type" content="${type}">
<meta property="og:site_name" content="Riffle by Aignix">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${url}">
<meta property="og:image" content="${img}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="Riffle previewing a folder in macOS Quick Look">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${img}">
<link rel="icon" type="image/png" href="/favicon.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="alternate" type="application/rss+xml" title="Riffle blog" href="${SITE.url}/feed.xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">
<link rel="stylesheet" href="/assets/css/site.css">
${jsonld.map((j) => `<script type="application/ld+json">${JSON.stringify(j)}</script>`).join("\n")}
${extra}
</head>`;
}

function header(active = "") {
  const links = nav
    .map(([href, label]) => `<li><a href="${href}"${active === href ? ' aria-current="page"' : ""}>${label}</a></li>`)
    .join("");
  return `<a class="skip" href="#main">Skip to content</a>
<header class="site-header">
  <nav class="wrap nav" aria-label="Main">
    <a class="brand" href="/"><img src="/assets/img/icon-256.webp" alt="" width="28" height="28">Riffle <span>by Aignix</span></a>
    <button class="btn menu-toggle" aria-expanded="false" aria-controls="nav-links">Menu</button>
    <ul class="nav-links" id="nav-links">${links}<li><a href="${SITE.repo}" rel="noopener">GitHub</a></li></ul>
    <a class="btn primary" href="${SITE.download}">${icon.download}Download</a>
  </nav>
</header>`;
}

function footer() {
  return `<footer class="site-footer">
  <div class="wrap">
    <ul class="foot-links">
      <li><a href="${SITE.download}">Download</a></li>
      <li><a href="${SITE.releases}" rel="noopener">Release notes</a></li>
      <li><a href="${SITE.repo}" rel="noopener">Source code</a></li>
      <li><a href="/blog">Blog</a></li>
      <li><a href="/blog/folder-sizes-mac">Folder sizes on a Mac</a></li>
      <li><a href="/blog/best-folder-preview-apps-mac">Folder preview apps compared</a></li>
      <li><a href="${SITE.maker.url}">Aignix</a></li>
    </ul>
    <p class="credits">© 2026 Aignix · <a href="${SITE.repo}/blob/main/LICENSE" rel="noopener">MIT License</a> · Built on <a href="https://github.com/altic-dev/PeekX" rel="noopener">PeekX</a> by ALTIC (MIT). Mac, Finder and Quick Look are trademarks of Apple Inc.; Riffle isn't affiliated with Apple. This site has no cookies and no analytics.</p>
  </div>
</footer>
<script src="/assets/js/site.js" defer></script>
</body>
</html>`;
}

const page = (opts, body, active) => `${head(opts)}
<body>
${header(active)}
<main id="main">
${body}
</main>
${footer()}`;

// ── front matter ──────────────────────────────────────────────────────────────
function parsePost(file) {
  const raw = readFileSync(file, "utf8");
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error(`No front matter in ${file}`);
  const data = {};
  for (const line of m[1].split("\n")) {
    const i = line.indexOf(":");
    if (i < 0) continue;
    const key = line.slice(0, i).trim();
    let value = line.slice(i + 1).trim();
    if (value.startsWith('"') && value.endsWith('"')) value = value.slice(1, -1);
    data[key] = key === "related" ? value.split(",").map((s) => s.trim()).filter(Boolean) : value;
  }
  data.slug = path.basename(file, ".md");
  data.body = fill(m[2]);
  data.words = data.body.split(/\s+/).filter(Boolean).length;
  data.minutes = Math.max(1, Math.round(data.words / 230));
  return data;
}

const fmtDate = (iso) =>
  new Date(iso + "T00:00:00Z").toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

// ── build ─────────────────────────────────────────────────────────────────────
rmSync(DIST, { recursive: true, force: true });
mkdirSync(path.join(DIST, "blog"), { recursive: true });
cpSync(path.join(SRC, "assets"), path.join(DIST, "assets"), { recursive: true });
for (const f of ["og.jpg", "favicon.png", "apple-touch-icon.png"]) cpSync(path.join(SRC, f), path.join(DIST, f));

const posts = readdirSync(path.join(SRC, "blog"))
  .filter((f) => f.endsWith(".md"))
  .map((f) => parsePost(path.join(SRC, "blog", f)))
  .sort((a, b) => (a.order ?? 99) - (b.order ?? 99));
const bySlug = Object.fromEntries(posts.map((p) => [p.slug, p]));

const orgLd = { "@type": "Organization", name: SITE.maker.name, url: SITE.maker.url };
const appLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Riffle",
  description: "A free, open-source Quick Look extension that shows a folder's contents, real folder sizes, thumbnails and file details when you press Space in Finder.",
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "macOS 14 or later",
  softwareVersion: SITE.version,
  fileSize: SITE.dmgSize,
  downloadUrl: SITE.download,
  url: SITE.url,
  image: SITE.url + "/og.jpg",
  license: SITE.repo + "/blob/main/LICENSE",
  isAccessibleForFree: true,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  author: orgLd,
};

// Landing page
const landing = fill(readFileSync(path.join(SRC, "index.html"), "utf8"));
const faqLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: [...landing.matchAll(/<details[^>]*>\s*<summary>([\s\S]*?)<\/summary>\s*<div>([\s\S]*?)<\/div>\s*<\/details>/g)].map((m) => ({
    "@type": "Question",
    name: m[1].replace(/<[^>]+>/g, "").trim(),
    acceptedAnswer: { "@type": "Answer", text: m[2].replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim() },
  })),
};
writeFileSync(
  path.join(DIST, "index.html"),
  page(
    {
      title: "Riffle — free folder preview for Mac Quick Look",
      description: "Press Space on any folder in Finder and see everything inside: files, real folder sizes, thumbnails and details. Free and open source for macOS.",
      canonical: "/",
      jsonld: [appLd, faqLd, { "@context": "https://schema.org", "@type": "WebSite", name: "Riffle", url: SITE.url, publisher: orgLd }],
    },
    landing,
  ),
);

// Blog posts
for (const post of posts) {
  const related = (post.related ?? []).map((s) => bySlug[s]).filter(Boolean);
  const url = `${SITE.url}/blog/${post.slug}`;
  const body = `<article class="wrap article">
  <p class="crumbs"><a href="/">Riffle</a> / <a href="/blog">Blog</a></p>
  <h1>${esc(post.title)}</h1>
  <p class="lead">${esc(post.description)}</p>
  <p class="meta">${fmtDate(post.date)} · ${post.minutes} min read · Aignix</p>
  ${post.disclosure ? `<p class="disclosure">${esc(post.disclosure)}</p>` : ""}
  <div class="prose">
${marked.parse(post.body, { gfm: true })}
  </div>
  <aside class="card cta-card">
    <img src="/assets/img/icon-256.webp" alt="" width="56" height="56">
    <div><h3>Try Riffle, free</h3><p>Press Space on a folder and see everything inside. ${SITE.dmgSize}, ${SITE.minOS}.</p></div>
    <a class="btn primary" href="${SITE.download}">${icon.download}Download for Mac</a>
  </aside>
  ${related.length ? `<nav class="related" aria-label="Related guides"><h2>Keep reading</h2><ul>${related.map((r) => `<li><a href="/blog/${r.slug}">${esc(r.title)}</a></li>`).join("")}</ul></nav>` : ""}
</article>`;
  const ld = [
    {
      "@context": "https://schema.org",
      "@type": "BlogPosting",
      headline: post.title,
      description: post.description,
      datePublished: post.date,
      dateModified: post.updated || post.date,
      author: orgLd,
      publisher: { ...orgLd, logo: { "@type": "ImageObject", url: SITE.url + "/apple-touch-icon.png" } },
      mainEntityOfPage: url,
      image: SITE.url + "/og.jpg",
      wordCount: post.words,
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Riffle", item: SITE.url + "/" },
        { "@type": "ListItem", position: 2, name: "Blog", item: SITE.url + "/blog" },
        { "@type": "ListItem", position: 3, name: post.title, item: url },
      ],
    },
  ];
  writeFileSync(
    path.join(DIST, "blog", `${post.slug}.html`),
    page({ title: post.seoTitle || `${post.title} | Riffle`, description: post.description, canonical: `/blog/${post.slug}`, type: "article", jsonld: ld, extra: `<meta property="article:published_time" content="${post.date}">` }, body, "/blog"),
  );
}

// Blog index
const list = posts
  .map((p) => `<a class="card post-card" href="/blog/${p.slug}"><span class="meta">${fmtDate(p.date)} · ${p.minutes} min read</span><h2>${esc(p.title)}</h2><p>${esc(p.description)}</p></a>`)
  .join("\n");
writeFileSync(
  path.join(DIST, "blog", "index.html"),
  page(
    { title: "Riffle blog: Mac folder tips, Quick Look guides and comparisons", description: "Guides for seeing folder contents and sizes on a Mac, Quick Look tips, and honest comparisons of folder preview apps.", canonical: "/blog" },
    `<div class="wrap"><header class="page-head"><h1>Guides for people who live in folders</h1><p>How to see folder sizes, look inside folders without opening them, and which Quick Look tools are worth installing.</p></header><div class="post-list">${list}</div></div>`,
    "/blog",
  ),
);

// 404
writeFileSync(
  path.join(DIST, "404.html"),
  page({ title: "Page not found | Riffle", description: "This page doesn't exist.", canonical: "/404" }, `<div class="wrap"><header class="page-head" style="padding-bottom:96px"><h1>Nothing in this folder.</h1><p>The page you wanted isn't here. <a href="/">Go to the Riffle home page</a> or <a href="/blog">read the blog</a>.</p></header></div>`),
);

// sitemap, robots, RSS
const urls = [["/", SITE.published], ["/blog", SITE.published], ...posts.map((p) => [`/blog/${p.slug}`, p.updated || p.date])];
writeFileSync(
  path.join(DIST, "sitemap.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(([u, d]) => `  <url><loc>${SITE.url}${u === "/" ? "/" : u}</loc><lastmod>${d}</lastmod></url>`).join("\n")}\n</urlset>\n`,
);
writeFileSync(path.join(DIST, "robots.txt"), `User-agent: *\nAllow: /\n\nSitemap: ${SITE.url}/sitemap.xml\n`);
writeFileSync(
  path.join(DIST, "feed.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0"><channel><title>Riffle blog</title><link>${SITE.url}/blog</link><description>Mac folder tips and Quick Look guides from Aignix.</description>\n${posts.map((p) => `<item><title>${esc(p.title)}</title><link>${SITE.url}/blog/${p.slug}</link><guid>${SITE.url}/blog/${p.slug}</guid><pubDate>${new Date(p.date + "T08:00:00Z").toUTCString()}</pubDate><description>${esc(p.description)}</description></item>`).join("\n")}\n</channel></rss>\n`,
);

console.log(`Built ${posts.length} posts + landing → ${path.relative(process.cwd(), DIST) || "dist"}`);
for (const p of posts) console.log(`  /blog/${p.slug}  (${p.words} words)`);
