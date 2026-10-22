# Riffle — Project Context

## ⏸️ RESUME HERE
- **Updated:** 2026-10-22 (account 1)
- **Last worked:** Built the website: landing page + 5 SEO guides, deployed to Vercel (project `riffle`, team `cutlume1`). Shipped **app v1.0.1** (column-width polish, footer → website, stable `Riffle.dmg` asset).
- **Current state:** Site LIVE at https://riffle-ten.vercel.app. `riffle.aignix.online` is attached to the Vercel project but **waits on one DNS record at Hostinger**: `CNAME riffle → 81d2c86bda68e0bd.vercel-dns-017.com` (Vercel's rank-2 fallback, `cname.vercel-dns.com`, also works). App v1.0.1 is live on GitHub, and the download link `…/releases/latest/download/Riffle.dmg` was verified (SHA matches).
- **NEXT STEP:** Add the CNAME (Prince does it in hPanel, or Claude does it through his logged-in Chrome once he says yes) → `npx vercel domains verify riffle.aignix.online --scope cutlume1` from `site/` → confirm HTTPS → submit `https://riffle.aignix.online/sitemap.xml` in Google Search Console + Bing (needs Prince's login; aignix.online may need a Domain property first).
- **Already done:** app v1.0.0 + v1.0.1 · GitHub repo + releases · site (landing, tour, comparison, FAQ, 5 posts, sitemap/robots/RSS/JSON-LD/OG image) · demo-folder screenshots only (Prince's rule: never show his real files).
- **Open decisions for Prince:** Apple Developer ID ($99/yr) to notarize · move to riffle.aignix.com when aignix.com is bought (change `SITE.url` in `site/build.mjs` + 301 the old host).

## Website (site/)
- `node site/build.mjs` → `site/dist/`. Landing = `site/src/index.html`. Posts = `site/src/blog/*.md` (front matter: title, seoTitle, description, date, order, disclosure, related). Tokens like `{{download}}`, `{{dmgSize}}`, `{{repo}}` are filled at build time.
- **One place to change domain/version/download:** the `SITE` object at the top of `site/build.mjs`.
- Deploy: `cd site && npx vercel deploy --prod --yes --scope cutlume1` (Vercel runs `node build.mjs`; `vercel.json` sets cleanUrls + headers).
- Brand = Aignix guideline (navy #05070D, one accent #208ADF, Space Grotesk/Inter/DM Mono, glow only on clickables, accent buttons labelled in navy). Only the closing CTA is centred.
- Screenshots come from a generated demo folder ("Launch Campaign": ffmpeg gradients, never real files), rendered by `scripts/harness.sh` (folder UI) and `scripts/mdshot` (markdown). Share image: `site/tools/og.swift` → `og.jpg` (kept <300 KB for WhatsApp).
- Competitor facts (prices, features) were checked 2026-10-22 from App Store/developer pages and are cited in the posts. Re-check before updating any comparison.

## What it is
A free, open-source macOS Quick Look extension. Select a folder in Finder, press Space, and see its contents (sizes, dates, kinds, expandable subfolders) plus a preview/details pane for any file you click. Purpose: a free tool Prince gives away on the Aignix page, to build following and show the team can build things.

Origin: fork of PeekX by ALTIC (MIT, github.com/altic-dev/PeekX). The MIT license **requires** keeping ALTIC's copyright notice. It's in LICENSE and the README credits it. Don't remove it.

## Folder map
```
App/            host app (welcome window) — main.swift, Info.plist
Extension/      Quick Look extension — PreviewViewController.swift, DocumentRenderer.swift, Info.plist, entitlements
Resources/      marked.min.js (vendored), AppIcon.icns, AppIcon-1024.png
scripts/        build.sh (build/sign/DMG/--install), harness.sh + harness/ (offscreen layout test), make_icon.swift
docs/           this file, ARCHITECTURE.md, INSTALL.txt (goes into the DMG), images/ (README art)
Versions/       VERSIONS.md, CURRENT.md, v1.0/ snapshot
build/, dist/   build output (gitignored)
```

## Pipeline
1. Edit source → `scripts/harness.sh "<folder>" /tmp/shot 808 600 "-1,0,3"` and look at the PNGs.
2. `scripts/build.sh --install` → `qlmanage -p <folder>` for the live check.
3. Release: bump `VERSION`/`BUILD` in scripts/build.sh → build → new `Versions/vX.Y/` snapshot + VERSIONS.md/CURRENT.md → **STOP: Prince approves** → GitHub release.

## Hard rules
- Keep the ALTIC copyright + "Based on PeekX" credit (MIT condition).
- Nothing gets pushed or published to GitHub without Prince's explicit OK.
- Never claim notarization, or that it "works on all Macs", without testing. It's tested on macOS 27 (Apple silicon); the Intel slice compiles but hasn't been run.
- Don't claim `public.plain-text` in the extension. It would hijack every code/text preview on the user's Mac.
