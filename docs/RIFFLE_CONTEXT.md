# Riffle — Project Context

## ⏸️ RESUME HERE
- **Updated:** 2026-10-22 (account 1)
- **Decision (Prince, 2026-10-22):** Riffle lives on **GitHub only**. No website: the Vercel project `riffle` was deleted on his instruction, and the site code is archived locally in `archive/website-2026-10-22/` (gitignored). The landing-page and blog request was actually meant for **Moodwall** (queued in Moodwall's context).
- **Current state:** v1.0.2 LIVE: https://github.com/princeyadav841426/Riffle/releases/tag/v1.0.2. The download link `…/releases/latest/download/Riffle.dmg` was verified (SHA 219c1055…dd69). README rebuilt: light/dark poster banner, demo GIF, light/dark screenshots (video, photo, PDF, folder, markdown), install for macOS 15+/14/Terminal, how-to-use, troubleshooting, FAQ, build, credits. Repo description, homepage and 10 topics set. GitHub detects MIT (credits moved to NOTICE.md), and languages show Swift/Shell (marked is vendored via .gitattributes). v1.0.1 notes say it's superseded.
- **NEXT STEP:** Nothing required. Optional for Prince: upload `docs/images/banner-light.png` as the repo's **social preview** (GitHub → Settings → General → Social preview; this has no API). Re-check his click-through test in real Quick Look if he reports anything.
- **Visual assets:** all from the generated demo folder ("Launch Campaign", never Prince's files). Regenerate with `HARNESS_LIGHT=1 scripts/harness.sh "<demo>" <out> 1040 540 "7,5,6,0"` (light), the same without `HARNESS_LIGHT` (dark), `build/harness/mdshot` (`MDSHOT_DARK=1` for dark), `swift scripts/make_banner.swift light|dark <icon> <shot> <out>`, and ffmpeg concat → GIF (palettegen).
- **Open decisions for Prince:** Apple Developer ID ($99/yr) for notarization. The Intel slice is untested on real Intel hardware.

## Website (archived, not live)
- `node site/build.mjs` → `site/dist/`. Landing = `site/src/index.html`. Posts = `site/src/blog/*.md` (front matter: title, seoTitle, description, date, order, disclosure, related). Tokens like `{{download}}`, `{{dmgSize}}`, `{{repo}}` are filled at build time.
- **One place to change domain/version/download:** the `SITE` object at the top of `site/build.mjs`.
- Deploy: `cd site && npx vercel deploy --prod --yes --scope cutlume1` (Vercel runs `node build.mjs`; `vercel.json` sets cleanUrls + headers).
- **Design = Moodwall's light system (Prince, 2026-10-22: "no dark, not the Aignix colours, no AI slop").** Canvas #f6f6f6, white cards with hairline shadows, Inter only, one blue (#3b7cf5; #2f6fe4 for text/buttons), pastel note cards (yellow/pink/green/blue) for use cases, a dot-grid "board" behind the hero shot, Moodwall .btn styles. Banned here: dark theme, gradients, glows, glass, grain, fake window chrome, icon grids, uppercase eyebrow labels.
- Screenshots come from a generated demo folder ("Launch Campaign": ffmpeg gradients, never real files), rendered in LIGHT mode by `HARNESS_LIGHT=1 scripts/harness.sh "<demo>" <out> 1040 540 "0,5,7"` (folder UI) and `build/harness/mdshot` (markdown, light by default). Share image: `site/tools/og.swift` → `og.jpg` (kept <300 KB for WhatsApp).
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
