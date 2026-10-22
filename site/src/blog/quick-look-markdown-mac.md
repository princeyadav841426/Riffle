---
title: How to preview Markdown files in Quick Look on a Mac
seoTitle: How to preview Markdown files in Quick Look on Mac (free) | Riffle
description: Press Space on a .md file and macOS shows raw text full of # and ** symbols. Here's how to get formatted Markdown previews, with tables and code blocks, using free Quick Look extensions.
date: 2026-10-22
order: 5
disclosure: We make Riffle, one of the options below. We also recommend another free tool where it's the better fit.
related: preview-folder-contents-mac, best-folder-preview-apps-mac, folder-preview-alternative
---

Select a README in Finder and press <kbd>Space</kbd>. macOS's built-in Quick Look treats Markdown as plain text, so you see the source: hash marks for headings, asterisks for bold, and tables as rows of pipes and dashes.

It's readable, barely. For a long README, release notes or a project brief, you want the formatted version. That means a Quick Look extension. Here are the free ones, how to set them up, and which to pick.

## What a Markdown preview should show

A good preview turns this:

```markdown
## Deliverables

| Asset | Format | Due |
|---|---|---|
| Teaser | 16:9, 30 s | Fri |

- Keep the hook under **2 seconds**.
```

into real headings, a real table, real bullets and real bold text. It should also render fenced code blocks, links and quotes, follow your Mac's light or dark mode, and never run scripts hidden in the file.

## Option 1: Riffle (free, open source)

[Riffle](/) is our free Quick Look extension. Its main job is folders, showing what's inside one when you press Space, but it also handles Markdown files:

<figure>
<img src="/assets/img/shot-markdown.webp" width="1640" height="1120" alt="A Markdown project brief rendered by Riffle in Quick Look, with headings, a table and a bulleted list" loading="lazy" decoding="async">
<figcaption>A project brief, previewed with Space.</figcaption>
</figure>

- **GitHub-style Markdown:** headings, tables, fenced code blocks, task lists, quotes, links and images from the web.
- **Works offline.** The Markdown library (marked) ships inside the app, so nothing is downloaded when you preview a file.
- **Safe by default.** The preview runs with JavaScript turned off, so a `<script>` tag in a file can't do anything.
- **Inside folders too.** Press Space on a folder, click a `.md` file in the list, and it renders in the side pane.
- **Follows light and dark mode.**

Very large files are cut off at 2 MB to keep the preview instant. There's no syntax colouring in code blocks and no theme settings. If you want those, see option 2.

**Set it up:** [download Riffle](/) ({{dmgSize}}), drag it to Applications, open it once and approve it in **System Settings → Privacy & Security → Open Anyway**. When it shows a green tick, Space on a `.md` file shows the formatted page.

## Option 2: QLMarkdown (free, open source)

If Markdown is most of your day, [QLMarkdown by sbarex](https://github.com/sbarex/QLMarkdown) is the specialist. It's free and open source, built on GitHub's own `cmark-gfm` parser, and it comes with a settings app for controlling how previews look. It also previews related formats such as R Markdown (`.rmd`), Quarto (`.qmd`) and MDX (`.mdx`).

The easiest install is Homebrew:

```bash
brew install --cask qlmarkdown
```

Then open QLMarkdown once from Applications so macOS registers its extension. Like Riffle, it isn't distributed through the App Store, so macOS may ask you to approve it the first time.

If you want something with no settings at all, a separate minimal plugin also called [QLMarkdown, by relikd](https://github.com/relikd/QLMarkdown), exists too.

## Option 3: Folder Quick Look (paid)

[Folder Quick Look](https://apps.apple.com/app/id6753110395) ($4.99, macOS 15.6 or later) is a folder preview app that added Markdown previews in version 1.6. Worth considering only if you'd buy it for its folder and archive previews anyway.

## Which one should you use?

| You mostly… | Pick |
|---|---|
| Browse folders and sometimes open a README | Riffle: folder previews plus Markdown, one app |
| Write and read Markdown all day, want themes and options | QLMarkdown (sbarex) |
| Already bought Folder Quick Look | Use its built-in Markdown preview |

## Only one extension can win

macOS sends each file type to one Quick Look extension. If you install both Riffle and QLMarkdown, macOS picks one for `.md` files, and it may not be the one you want. To choose:

- **macOS 15 and later:** System Settings → General → Login Items & Extensions → Quick Look
- **macOS 14:** System Settings → Privacy & Security → Extensions → Quick Look

Switching an extension off there turns it off for every file type it handles. Riffle has one switch for both folders and Markdown, so turning it off loses folder previews too. If you want QLMarkdown for `.md` files and Riffle for folders, install both and press Space on a `.md` file to see which one answers. If it's Riffle, you'll need to choose between them for now.

## Troubleshooting

**Space still shows plain text.** Open the extension's app once, so macOS registers it, and check that it's switched on in the settings above. If it still doesn't change, relaunch Finder (hold <kbd>⌥</kbd>, right-click the Finder icon in the Dock, choose **Relaunch**) or log out and back in.

**The file has a `.txt` extension.** Quick Look decides by file type, not content. Markdown extensions only receive `.md` and `.markdown` files. Rename the file if you want the formatted preview.

**Images don't show.** Images linked from the web load. Images stored next to the file, referenced by a relative path, may not appear, because Quick Look extensions run in a sandbox with limited file access.
