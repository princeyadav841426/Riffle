---
title: Best folder preview apps for Mac in 2026: Riffle vs Folder Preview vs Folder Quick Look
seoTitle: Best folder preview apps for Mac (2026): Riffle vs Folder Preview vs Folder Quick Look
description: Three Quick Look apps that show a folder's contents when you press Space. What each one costs, what it does, where it falls short, and which one to install.
date: 2026-10-22
order: 3
disclosure: We make Riffle, so read this with that in mind. Every competitor detail below comes from the developer's own App Store listing or website, checked on 22 October 2026, and we say plainly where Riffle loses.
related: folder-preview-alternative, folder-sizes-mac, quick-look-markdown-mac
---

Press <kbd>Space</kbd> on a folder in Finder and macOS shows you a folder icon. A folder preview app replaces that icon with the folder's actual contents, so you can see what's inside without opening it.

Three apps do this well in 2026: **Riffle**, **Folder Preview** and **Folder Quick Look**. They all plug into Quick Look the same way, and they're all small. Where they differ is price, archive support, how much detail you get, and which version of macOS you need.

## The short answer

- **You want it free, or you care about open source:** Riffle.
- **You need to look inside ZIP, RAR or 7z files:** Folder Preview.
- **You're on macOS 15.6 or newer and want a grid of image thumbnails:** Folder Quick Look.

The rest of this post explains why.

## Side-by-side

| | Riffle | Folder Preview | Folder Quick Look |
|---|---|---|---|
| Developer | Aignix | Anybox | App ahead |
| Price | Free | $1.99–2.99, Pro $9.99 | $4.99 |
| Open source | Yes, MIT | No | No |
| macOS | 14 or later | 12 or later | 15.6 or later |
| Folder sizes | Every subfolder, recursive | Yes | Yes, with a total summary |
| Browse subfolders | Expand inline | Pro: nested browsing | Not listed |
| Thumbnails | Images, video, PDF, documents | Images, video, PDF, SVG, EPS | Images, with a grid view |
| File details | Side pane: kind, size, dimensions, items, dates | Configurable columns | Summary line |
| Markdown files | Rendered | Not listed | Rendered |
| ZIP / RAR / 7z | No | Yes, plus TAR, GZ, BZ2, XZ | ZIP and RAR |
| Other file managers | Not tested | ForkLift, Path Finder, Commander One, QSpace, Bloom | Not listed |

Prices are from the US Mac App Store and the developers' sites, and they vary by region. "Not listed" means the developer doesn't describe that feature, not that it can't exist.

## Riffle

**Price:** free · **Needs:** macOS 14+ · **Made by:** Aignix

<figure>
<img src="/assets/img/shot-photo.webp" width="2080" height="1080" alt="Riffle previewing a folder with an image selected, showing its dimensions" loading="lazy" decoding="async">
</figure>

Riffle shows the folder as a sortable list: Name, Date Modified, Size and Kind. Every subfolder gets its full recursive size, measured in the background, and you can expand subfolders inside the preview. Click any file and a side pane shows a thumbnail (images, video frames, PDFs, documents) along with kind, size, pixel dimensions, item count and dates. Long file names wrap instead of being cut off. Filter tabs narrow the list to Folders, Images, Docs or Media, and the divider between list and preview drags.

It also renders Markdown files as formatted pages, offline, using a copy of the marked library bundled with the app. Scripts inside documents never run.

**Where it wins:** it costs nothing, the source code is public, and the details pane gives you the most information per click.

**Where it loses:**

- No archive previews. If you live in ZIP files, this matters.
- It isn't notarized by Apple, so the first launch needs one trip to **Privacy & Security → Open Anyway**.
- It's the newest of the three, built on the open-source PeekX project.

## Folder Preview by Anybox

**Price:** $1.99–2.99 on the Mac App Store, depending on region; Pro is $9.99 from the developer's site · **Needs:** macOS 12+

Folder Preview is the most established of the three, and its strongest feature is archives. It previews the contents of ZIP, RAR, 7z, TAR, GZ, BZ2 and XZ files without unpacking them. It also works in third-party file managers, and the developer lists ForkLift, Bloom, Path Finder, Commander One and QSpace by name.

You can choose which columns appear (image dimensions, for example), copy files or paths from the preview, and switch to an Icons view. Recent versions added video and EPS thumbnails and made folder size calculation faster. Anybox says the app makes no network requests.

The **Pro** version adds double-click to open files and folders, drag and drop out of the preview, a toolbar, and a dual-column layout. Its Setapp listing also mentions browsing nested folders.

**Where it wins:** archives, file-manager support, and a long track record.

**Where it loses:** it's paid and closed source, the most useful extras are in the $9.99 Pro version, and the developer doesn't list Markdown rendering.

## Folder Quick Look by App ahead

**Price:** $4.99 · **Needs:** macOS 15.6+

Folder Quick Look previews folders and archives, including ZIP and RAR. Its update history shows steady additions: a summary of total size and item count, image thumbnails inside folders, a remembered sort order, a grid view for image-heavy folders, Markdown previews, and more precise size calculations.

**Where it wins:** the grid view is good for folders full of photos, and it handles both archives and Markdown in one app.

**Where it loses:** it's the most expensive of the three, it needs macOS 15.6 or later, and at the time of writing its App Store page didn't have enough ratings to show a score.

## What about doing it without an app?

Finder can get you part of the way. Column view (<kbd>⌘</kbd> <kbd>3</kbd>) shows a folder's contents as you select it. List view lets you <kbd>⌥</kbd>-click a disclosure triangle to expand every subfolder, and **View Options → Calculate all sizes** fills in folder sizes. None of that works from Quick Look, and none of it gives you a preview pane. If you want to stay app-free, our guide to [seeing inside folders without opening them](/blog/preview-folder-contents-mac) covers each trick.

## Can you install more than one?

You can, but only one app can answer <kbd>Space</kbd> for folders at a time. macOS picks one, and it isn't always the one you expect. If you switch apps, turn the old one off: on macOS 15 and later, go to **System Settings → General → Login Items & Extensions → Quick Look**. On macOS 14, it's **System Settings → Privacy & Security → Extensions → Quick Look**. Or just delete the app you're not using.

## Our recommendation

Start with Riffle, because it's free and takes two minutes to try. If you find yourself wanting to look inside archives, Folder Preview at $1.99–2.99 is money well spent, and its Pro version is the most powerful of the three. If you're on the latest macOS and mostly browse folders of images, Folder Quick Look's grid view is worth a look.

Looking specifically for no-cost options? See [free alternatives to Folder Preview for Mac](/blog/folder-preview-alternative).

### Sources

- Folder Preview: [Mac App Store listing](https://apps.apple.com/app/folder-preview/id6698876601) and [Anybox's product page](https://anybox.ltd/folder-preview)
- Folder Preview Pro: [Setapp listing](https://setapp.com/apps/folder-preview-pro)
- Folder Quick Look: [Mac App Store listing](https://apps.apple.com/app/id6753110395)
- Riffle: [source code on GitHub]({{repo}})
