# Riffle — Architecture

Two bundles, no Xcode project. `scripts/build.sh` compiles both with `swiftc` (Command Line Tools only).

```
Riffle.app                      host app: welcome window, registers the extension (App/main.swift)
└─ Contents/PlugIns/RiffleExt.appex   Quick Look preview extension (sandboxed)
     ├─ PreviewViewController   folder UI + preview pane (Extension/PreviewViewController.swift)
     ├─ DocumentRenderer        markdown/text → HTML via bundled marked.js in JavaScriptCore
     └─ Resources/marked.min.js marked v11.1.1 (MIT), vendored
```

## Extension facts that cost time to learn
- An `.appex` must be a Mach-O **executable** entered at `_NSExtensionMain` (`-Xlinker -e -Xlinker _NSExtensionMain`), not a bundle. Linked as a bundle, `pkd` silently never registers it. Ad-hoc signing is fine for local use.
- **Don't use NSSplitView** in the preview. Inside the Quick Look remote view it ignores `setPosition` and pins the second pane at its minimum width. That was the original "text cropped on the right" bug, and it's also why the divider never dragged. The layout is a plain row: list | `PaneDivider` | preview pane. The pane's width constraint sits at priority 490 (below window-resize 500) with hard floors at 997/998, so it never blocks the Quick Look window from shrinking.
- Multi-line `NSTextField`s need `preferredMaxLayoutWidth` kept in sync with the pane (`updatePreviewWrapWidths()`), or they lay out at one-line width and get clipped.
- Columns are fitted manually (`fitColumnsToList()`, `noColumnAutoresizing`, `.fullWidth` style, clip-view frame observer). AppKit autoresizing plus the inset table style made Date/Size truncate in live Quick Look.
- WKWebView in a sandbox draws **nothing** without `com.apple.security.network.client`, even for local HTML. JavaScript is disabled in the web views; marked runs natively in JavaScriptCore instead.
- `screencapture -l <window>` can't see WebKit's out-of-process layer. Use `WKWebView.takeSnapshot` (DEBUG builds save `web-snapshot.png` to the extension's tmp) or a full-screen capture.

## Testing
- `scripts/harness.sh <folder> <out> [w] [h] [rows]` builds the real controller into an offscreen window and writes PNGs + frame metrics (`-D RIFFLE_HARNESS`). It doesn't capture WebKit.
- Live: `scripts/build.sh --install`, then `qlmanage -p <folder>`.
- Debug logging: `RIFFLE_SWIFT_FLAGS="-D DEBUG" scripts/build.sh --install` → `~/Library/Containers/com.aignix.riffle.preview/Data/tmp/RiffleExt.log`.

## Identifiers
- App `com.aignix.riffle` · extension `com.aignix.riffle.preview`
- Handles `public.folder` and `net.daringfireball.markdown` only. It deliberately does **not** claim `public.plain-text`, so Apple's text/code previews stay untouched.
