---
title: How to see what's inside a folder on a Mac without opening it
seoTitle: How to see what's inside a folder on Mac without opening it | Riffle
description: Quick Look previews files, not folders. Here's how to check a folder's contents from Finder without opening it, using built-in shortcuts and a free Quick Look add-on.
date: 2026-10-22
order: 2
related: folder-sizes-mac, quick-look-markdown-mac, best-folder-preview-apps-mac
---

Quick Look is one of the best things about a Mac. Select a file, press <kbd>Space</kbd>, and you see it: a photo, a PDF, a video, a spreadsheet. No app opens. Press <kbd>Space</kbd> again and it's gone.

Try the same thing on a folder and you get a big folder icon and a few lines of information. Nothing about what's inside.

That gap costs time all day: open the folder, scan it, go back, open the next one. Here's how to see inside folders without the round trip, first with what's already on your Mac, then with a free add-on that makes <kbd>Space</kbd> work for folders.

## Quick Look in 30 seconds

- **Space** or <kbd>⌘</kbd> <kbd>Y</kbd> opens a preview of whatever is selected in Finder.
- **Arrow keys** move the selection while the preview stays open, so you can step through a folder of photos.
- <kbd>⌥</kbd> <kbd>Space</kbd> opens the preview full screen.
- Select several files first and Quick Look lets you page through all of them.

For files, that's all you need. For folders, read on.

## Built-in ways to peek inside a folder

### Column view shows a folder's contents as you select it

Switch a Finder window to Column view with <kbd>⌘</kbd> <kbd>3</kbd>. Click a folder (or arrow onto it) and its contents appear in the next column. You never open a new window. Keep pressing <kbd>→</kbd> to walk down the tree.

It's fast for one level at a time. It won't show sizes or a preview of files several folders deep.

### List view expands folders in place

In List view (<kbd>⌘</kbd> <kbd>2</kbd>), each folder has a disclosure triangle. Click it, or select the folder and press <kbd>→</kbd>, to show its contents indented underneath. Press <kbd>←</kbd> to fold it back.

Hold <kbd>⌥</kbd> while you click the triangle to expand **every** subfolder at once. On a big project folder that turns into a very long list, but it's the quickest built-in way to see everything.

### Get Info for the numbers

<kbd>⌘</kbd> <kbd>I</kbd> on a folder shows how many items it holds and how much space they take. It won't tell you what those items are. See [how to see folder sizes on a Mac](/blog/folder-sizes-mac) for more ways to get the numbers.

## Make Space work for folders with Riffle

[Riffle](/) is a free, open-source Quick Look extension that we make. Once it's installed, pressing <kbd>Space</kbd> on a folder shows what's inside it:

<figure>
<img src="/assets/img/shot-video.webp" width="2080" height="1280" alt="Riffle showing a folder's files and subfolders, with a video selected and its preview on the right" loading="lazy" decoding="async">
<figcaption>Press Space on a folder: the file list on the left, a preview and details for whatever you click on the right.</figcaption>
</figure>

What you get in that one preview:

- **Every file and subfolder**, with Date Modified, Size and Kind. Click a column header to sort.
- **Real folder sizes.** Each subfolder is measured all the way down, in the background.
- **Subfolders that open in place.** Click the arrow next to one to see inside without leaving the preview.
- **A preview pane.** Click a photo, video, PDF or document and its thumbnail appears on the right, with its kind, size, dimensions and dates.
- **Filters.** Show only Folders, Images, Docs or Media.
- **A divider you can drag** to make the preview pane wider. Riffle remembers your choice.

Press <kbd>Esc</kbd> or <kbd>Space</kbd> to close it, the same as any Quick Look preview.

### Setting it up

1. [Download Riffle](/) ({{dmgSize}}) and drag it into Applications.
2. Open it once. Because it's free and not sold through Apple, macOS asks you to confirm: click **Done**, then **System Settings → Privacy & Security → Open Anyway**.
3. When Riffle shows a green tick, close it. From now on, <kbd>Space</kbd> on any folder shows its contents.

Riffle only handles folders and Markdown files. Every other file type still uses Apple's own Quick Look previews, so nothing else on your Mac changes.

## Which method fits which job?

| Situation | Best tool |
|---|---|
| Walking down a folder tree one level at a time | Column view |
| Seeing everything in a project, nested | List view, <kbd>⌥</kbd>-click the triangle |
| "What's in here, and how big is it?" without opening anything | Riffle |
| One folder's total size and item count | Get Info |

## Real examples

**A video editor checking a card dump.** Select `01 Raw Footage`, press Space. Every clip shows with its size and date. Click one and a frame appears in the side pane. Close the preview and drag the right clip into the timeline.

**A designer checking an export folder.** Press Space on `Exports`. Filter to Images, click each file, and read the pixel dimensions in the details pane. The one exported at the wrong size shows up immediately.

**Clearing space before a big download.** Press Space on your Downloads folder, sort by Size, and the largest items are at the top.

## Quick answers

**Can Quick Look show folder contents without an app?**
No. Out of the box, Quick Look shows a folder's icon and basic information. To list the files inside, you need a Quick Look extension such as Riffle, or another of the [folder preview apps for Mac](/blog/best-folder-preview-apps-mac).

**Does a Quick Look extension slow my Mac down?**
Riffle starts when you open a preview, not before. Folder sizes are measured in the background, so the list appears straight away and sizes fill in as they're counted.

**Will it work in other file managers?**
Riffle plugs into macOS Quick Look. Apps that use the system's Quick Look panel can show it, but we test in Finder.
