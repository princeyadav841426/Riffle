---
title: Free alternatives to Folder Preview for Mac
seoTitle: Free alternatives to Folder Preview for Mac (open source) | Riffle
description: Don't want to pay for a folder preview app? Here are the free ways to see inside folders on a Mac, from open-source Quick Look extensions to tricks already built into Finder.
date: 2026-10-22
order: 4
disclosure: We make Riffle, one of the apps below. Riffle is built on PeekX, another app on this list, and we've tried to describe both fairly.
related: best-folder-preview-apps-mac, preview-folder-contents-mac, folder-sizes-mac
---

[Folder Preview](https://anybox.ltd/folder-preview) and [Folder Quick Look](https://apps.apple.com/app/id6753110395) are good apps. They make <kbd>Space</kbd> on a folder show its contents instead of an icon. They also cost money ($1.99 to $9.99 for Folder Preview depending on version and region, $4.99 for Folder Quick Look), and their code is closed.

If you'd rather not pay, or you want software whose code you can read, there are free options. Here are the ones worth knowing, and what each one gives up.

## 1. Riffle (free, open source)

[Riffle](/) is a free Quick Look extension from Aignix, released under the MIT license. Press <kbd>Space</kbd> on a folder and you get:

- a sortable list of every file and subfolder with dates, sizes and kinds
- **recursive folder sizes** for every subfolder, measured in the background
- subfolders you can expand inside the preview
- a side pane with thumbnails (images, video frames, PDFs, documents) and details: kind, size, pixel dimensions, item count, dates
- filters for Folders, Images, Docs and Media
- Markdown files rendered as formatted pages, offline

<figure>
<img src="/assets/img/shot-video.webp" width="2080" height="1080" alt="Riffle's Quick Look preview of a folder, with a video selected" loading="lazy" decoding="async">
</figure>

**What it gives up compared with the paid apps:** archive previews (no ZIP or RAR yet), and Apple notarization. Riffle isn't notarized, so the first launch needs one trip to **System Settings → Privacy & Security → Open Anyway**. After that it's the same as any other app.

**Needs:** macOS 14 or later, Apple silicon or Intel. **Size:** {{dmgSize}}.

## 2. PeekX (free, open source)

[PeekX](https://github.com/altic-dev/PeekX) by ALTIC is where Riffle started. It's MIT-licensed, free, and its download is signed and notarized by Apple, so it opens without the Privacy & Security step. Credit where it's due: the core idea and much of the folder list in Riffle come from PeekX.

PeekX shows a folder's contents in Quick Look with filter tabs, a preview pane for images, and Markdown support added in version 1.1. We built Riffle because we needed a few things version 1.1 doesn't do. From reading its source code:

- Subfolders show `—` in the Size column, and the header total only counts files directly inside the folder. Riffle measures every subfolder recursively.
- The list shows the first 500 items. Riffle shows up to 5,000.
- Markdown files opened with Space load their rendering library from the internet. Riffle bundles it, so it works offline.
- Videos and PDFs show their icon instead of a thumbnail, and file details are a one-line summary (size, kind, date) without pixel dimensions or item counts.

If PeekX's feature set covers what you need and you'd rather skip the Open Anyway step, it's a fine choice. Don't install both: only one extension can answer Space for folders.

## 3. Finder's built-in tools (free, already installed)

You can get partway there without installing anything:

- **Column view** (<kbd>⌘</kbd> <kbd>3</kbd>): select a folder and its contents appear in the next column.
- **List view expansion:** in List view, press <kbd>→</kbd> on a folder to show its contents underneath, or <kbd>⌥</kbd>-click its triangle to expand every subfolder.
- **Calculate all sizes:** **View → Show View Options** (<kbd>⌘</kbd> <kbd>J</kbd>) in List view puts real folder sizes in the Size column.
- **Get Info** (<kbd>⌘</kbd> <kbd>I</kbd>): one folder's size and item count.

**What it gives up:** none of this works from Quick Look, there's no side preview, and you have to change Finder's view to use it. Our guide to [seeing folder sizes on a Mac](/blog/folder-sizes-mac) goes through each method.

## 4. Terminal (free, for people who like typing)

```bash
ls -lhS ~/Downloads        # list a folder, biggest files first
du -sh ~/Downloads/* | sort -h   # every item's size on disk, ranked
```

Fast and exact, with no previews and no clicking. Handy for very large folders or for scripts.

## Free vs paid: what you'd be paying for

| | Riffle | PeekX | Finder alone | Folder Preview (paid) |
|---|---|---|---|---|
| Price | Free | Free | Free | $1.99–2.99, Pro $9.99 |
| Works on Space | Yes | Yes | No | Yes |
| Recursive folder sizes | Yes | No (v1.1) | Calculate all sizes | Yes |
| Thumbnails in preview | Images, video, PDF, docs | Images | No | Images, video, PDF, SVG, EPS |
| ZIP / RAR previews | No | No | No | Yes |
| Signed by Apple | No | Yes, notarized | — | Yes, Mac App Store |
| Source code | Public | Public | — | Closed |

The honest summary: **archives are the main thing money buys.** If you regularly need to look inside ZIP or RAR files without unpacking them, Folder Preview is worth its small price. If you don't, Riffle covers everyday folder browsing for free.

## How to switch from a paid app to Riffle

1. Quit and delete the old app (drag it from Applications to the Trash). This turns off its Quick Look extension.
2. [Download Riffle](/) and drag it into Applications.
3. Open it, confirm it in **Privacy & Security → Open Anyway**, and wait for the green tick.
4. Press <kbd>Space</kbd> on a folder.

If you still see the old app's preview, restart Finder (<kbd>⌥</kbd>-right-click the Finder icon in the Dock → Relaunch) or log out and back in.
