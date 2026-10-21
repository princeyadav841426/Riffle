// Riffle — folder preview for macOS Quick Look
// Copyright © 2026 Aignix. MIT License.

import Foundation
import JavaScriptCore

/// Turns markdown / plain-text files into a self-contained HTML page.
///
/// Markdown is converted by the bundled marked.js running inside JavaScriptCore, so previews
/// work offline and the web view that shows the result runs with JavaScript turned off.
enum DocumentRenderer {
    enum Style {
        case pane      // inside the folder preview's right-hand pane
        case fullPage  // a markdown file opened directly with Space
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mkdn", "mdx"]
    private static let maxBytes = 2 * 1024 * 1024

    private static let lock = NSLock()
    private static var context: JSContext?

    static func html(forFileAt url: URL, style: Style) -> String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return page(body: "<p class=\"note\">Could not read this file.</p>", style: style)
        }
        let truncated = data.count > maxBytes
        let slice = truncated ? data.prefix(maxBytes) : data
        let text = String(decoding: slice, as: UTF8.self)
        let note = truncated ? "<p class=\"note\">Showing the first 2 MB of this file.</p>" : ""

        if markdownExtensions.contains(url.pathExtension.lowercased()), let rendered = renderMarkdown(text) {
            return page(body: note + rendered, style: style)
        }
        return page(body: note + "<pre class=\"plain\">\(escape(text))</pre>", style: style)
    }

    private static func renderMarkdown(_ markdown: String) -> String? {
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "<p class=\"note\">This file is empty.</p>"
        }
        lock.lock()
        defer { lock.unlock() }
        if context == nil {
            guard let scriptURL = Bundle(for: BundleToken.self).url(forResource: "marked.min", withExtension: "js"),
                  let script = try? String(contentsOf: scriptURL, encoding: .utf8),
                  let ctx = JSContext() else { return nil }
            ctx.evaluateScript(script)
            guard ctx.objectForKeyedSubscript("marked")?.isUndefined == false else { return nil }
            context = ctx
        }
        guard let ctx = context,
              let parse = ctx.objectForKeyedSubscript("marked")?.objectForKeyedSubscript("parse"),
              let result = parse.call(withArguments: [markdown, ["gfm": true]]),
              result.isString else { return nil }
        return result.toString()
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func page(body: String, style: Style) -> String {
        let padding = style == .pane ? "16px 18px 24px" : "28px 48px 48px"
        let background = style == .pane ? "transparent" : "#ffffff"
        let darkBackground = style == .pane ? "transparent" : "#1e1e1e"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            :root { color-scheme: light dark; }
            body {
                margin: 0;
                padding: \(padding);
                font: 14px/1.6 -apple-system, BlinkMacSystemFont, sans-serif;
                color: #1d1d1f;
                background: \(background);
                overflow-wrap: anywhere;
            }
            .doc { max-width: 860px; margin: 0 auto; }
            h1, h2, h3, h4, h5, h6 { margin: 1.3em 0 0.6em; font-weight: 600; line-height: 1.25; }
            h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
            h1 { font-size: 1.8em; border-bottom: 1px solid rgba(142,142,147,0.3); padding-bottom: 6px; }
            h2 { font-size: 1.4em; border-bottom: 1px solid rgba(142,142,147,0.3); padding-bottom: 4px; }
            h3 { font-size: 1.2em; }
            p { margin: 0 0 14px; }
            a { color: #0969da; text-decoration: none; }
            code { font: 12.5px "SF Mono", Menlo, monospace; background: rgba(142,142,147,0.16); padding: 2px 5px; border-radius: 4px; }
            pre { background: rgba(142,142,147,0.1); padding: 12px 14px; border-radius: 8px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            pre.plain { font: 12.5px/1.5 "SF Mono", Menlo, monospace; white-space: pre-wrap; background: none; padding: 0; }
            ul, ol { margin: 0 0 14px; padding-left: 26px; }
            li { margin: 3px 0; }
            blockquote { margin: 0 0 14px; padding: 0 14px; border-left: 3px solid rgba(142,142,147,0.45); color: #57606a; }
            table { border-collapse: collapse; width: 100%; margin: 14px 0; display: block; overflow-x: auto; }
            th, td { border: 1px solid rgba(142,142,147,0.35); padding: 6px 10px; text-align: left; }
            th { background: rgba(142,142,147,0.12); font-weight: 600; }
            img { max-width: 100%; height: auto; border-radius: 6px; }
            hr { border: none; border-top: 1px solid rgba(142,142,147,0.35); margin: 20px 0; }
            .note { color: #8e8e93; font-size: 12px; }
            @media (prefers-color-scheme: dark) {
                body { color: #e5e5e7; background: \(darkBackground); }
                a { color: #58a6ff; }
                blockquote { color: #a1a1a6; }
            }
        </style>
        </head>
        <body><div class="doc">
        \(body)
        </div></body>
        </html>
        """
    }

    private final class BundleToken {}
}
