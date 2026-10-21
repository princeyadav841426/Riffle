# Riffle — Project Context

## ⏸️ RESUME HERE
- **Updated:** 2026-10-22 (account 1, after account 2 hit its limit mid-task)
- **Last worked:** Fixed the right-pane text cropping, rebranded PeekX → **Riffle**, built v1.0.0 + DMG, installed it on Prince's Mac, and moved the old PeekX.app to the Trash.
- **Current state:** v1.0.0 works in real Quick Look. Verified there: folder list, readable right pane, all four columns, markdown rendering. Selection states (video thumbnail, photo, long names, nested folder) were verified in the offscreen harness from the same code. Git repo initialised and committed locally. **Not on GitHub yet.**
- **NEXT STEP:** Once Prince says yes, create the public repo `princeyadav841426/Riffle`, push, and publish release `v1.0.0` with `dist/Riffle-1.0.0.dmg` (+ `.sha256`). The in-app footer link already points to that URL; a different name means editing `repoURL` in `App/main.swift` and rebuilding. Then Prince makes the Aignix video.
- **Already done:** source recovered from upstream + all 5 August patches re-applied · crop root cause found and fixed (NSSplitView ignored repositioning) · details pane · thumbnails · offline markdown · welcome app · icon · universal build · DMG · README + screenshots · docs.
- **Open decision for Prince:** Apple Developer ID ($99/yr) to notarize. Without it, every downloader has to click "Open Anyway" once. Everything works without it.

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
