---
title: How to see folder sizes on a Mac: 5 ways that work
seoTitle: How to see folder sizes on a Mac (5 ways that work) | Riffle
description: Finder shows two dashes where a folder's size should be. Here are five ways to see real folder sizes on macOS, from Get Info to Terminal, and when to use each one.
date: 2026-10-22
order: 1
related: preview-folder-contents-mac, best-folder-preview-apps-mac, folder-preview-alternative
---

Open a folder in Finder's List view and look at the Size column. Files have sizes. Folders get two dashes: `--`.

That's deliberate. To size a folder, macOS has to add up every file inside it, and every file inside its subfolders. On a project folder with 80,000 files, that takes a while, so Finder skips it to keep List view fast.

When you do need the number, here are five ways to get it, from one-off checks to every folder at once.

## 1. Get Info: exact, one folder at a time

Select the folder and press <kbd>⌘</kbd> <kbd>I</kbd>. In the window that opens, the **Size** line reads something like:

> 12,481,203 bytes (12.5 MB on disk) for 214 items

The first number is the total size of the files' contents. The second, "on disk", is the space they actually take up. More on why those differ [below](#why-two-sizes).

**Best for:** checking one folder. You can select several folders and press <kbd>⌥</kbd> <kbd>⌘</kbd> <kbd>I</kbd> to get one combined Inspector window, but you won't get a per-folder breakdown.

## 2. Turn on "Calculate all sizes" in List view

This puts real sizes in Finder's Size column for every folder:

1. Open the folder you care about and switch to List view (<kbd>⌘</kbd> <kbd>2</kbd>).
2. Choose **View → Show View Options** (<kbd>⌘</kbd> <kbd>J</kbd>).
3. Tick **Calculate all sizes**.
4. To apply it to every folder in List view, click **Use as Defaults**.

Sizes fill in a few seconds after the list appears, and you can sort by the Size column to find the heaviest folder.

**The catch:** it only works in List view, and on very large folders it can make Finder feel slower. That's the reason Apple leaves it off by default.

## 3. Terminal: `du` for exact numbers and rankings

`du` ("disk usage") is built into every Mac. Open Terminal and try:

```bash
du -sh ~/Movies
```

`-s` gives one total instead of listing every subfolder, and `-h` prints human-readable sizes like `48G`. To rank everything inside a folder, biggest last:

```bash
du -sh ~/Movies/* | sort -h
```

`du` reports space used on disk, the same idea as the "on disk" number in Get Info. Some protected folders (Mail, Messages, parts of `~/Library`) print `Operation not permitted` unless Terminal has Full Disk Access in **System Settings → Privacy & Security**. Add `2>/dev/null` to the end of the command to hide those lines.

**Best for:** huge folders, scripts, or when you want a ranked list you can copy.

## 4. Storage settings: the whole-disk view

Open **System Settings → General → Storage**. You get a bar showing how your disk splits across Applications, Documents, Photos, macOS and so on, with recommendations underneath.

Click the **ⓘ** next to a category such as Documents to see large files and a browser for that category. It's the right place to start when your Mac says the disk is almost full and you don't know where to look. It's the wrong tool for "how big is this one project folder?"

## 5. Riffle: every folder's size with one keypress

[Riffle](/) is a free Quick Look extension we make. Select any folder in Finder and press <kbd>Space</kbd>. Instead of a big folder icon, you get the folder's contents, and every subfolder's size fills in as Riffle measures it in the background.

<figure>
<img src="/assets/img/shot-folder.webp" width="2080" height="1280" alt="Riffle showing a project folder with a size next to every subfolder" loading="lazy" decoding="async">
<figcaption>Each subfolder gets its full size, measured all the way down. The total is in the header.</figcaption>
</figure>

A few details:

- Sizes match the **on disk** number in Get Info, so the two never disagree.
- Click the **Size** column to sort, and the heaviest folder moves to the top.
- Click a subfolder and the side pane shows its size, item count and dates.
- Use the arrow next to a subfolder to look inside it without leaving the preview.

**The limit:** to keep the preview fast, Riffle stops counting a folder after 200,000 files. For a folder that big (a full Photos library, say), use `du` from method 3.

[Download Riffle](/) — it's free, {{dmgSize}}, and needs {{minOS}}.

## Which one should you use?

| You want to… | Use |
|---|---|
| Check one folder, once | Get Info (<kbd>⌘</kbd> <kbd>I</kbd>) |
| See sizes every time you browse in List view | Calculate all sizes |
| Rank everything in a huge folder | `du -sh * \| sort -h` |
| Find out why the disk is full | Storage settings |
| Glance at a folder's subfolders and their sizes without opening it | Riffle (<kbd>Space</kbd>) |

<h2 id="why-two-sizes">Why does a folder have two different sizes?</h2>

Get Info shows a byte count and an "on disk" figure, and they rarely match.

A file's **size** is how much data it contains. Its **on disk** size is how much storage it actually occupies. Disks hand out space in fixed blocks, 4 KB each on a standard APFS Mac drive, so a 300-byte text file still occupies a full 4 KB block. A folder full of small files therefore takes noticeably more space on disk than its byte count suggests.

It can go the other way too. Files kept in iCloud Drive with **Optimize Mac Storage** turned on may be stored only in the cloud, so they report their full size while taking almost nothing on disk.

When you're freeing up space, the on disk number is the one that matters. It's the number Riffle and `du` show.

## Quick answers

**Why doesn't Finder show folder sizes by default?**
Sizing a folder means reading information about every file inside it. Apple turns that off in List view to keep browsing fast. You can turn it on with Calculate all sizes.

**Is there a keyboard shortcut for folder size?**
<kbd>⌘</kbd> <kbd>I</kbd> (Get Info) shows the size of the selected folder. With Riffle installed, <kbd>Space</kbd> shows the sizes of everything inside it.

**Why does the size keep changing after I open Get Info?**
macOS is still counting. For big folders the number climbs for a few seconds and then settles.
