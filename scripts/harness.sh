#!/bin/bash
# Build the offscreen layout harness. Usage: scripts/harness.sh <folder> <out-prefix> [w] [h] [rows]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/harness"
mkdir -p "$OUT"
swiftc -Onone -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" \
  -D RIFFLE_HARNESS -module-name RiffleHarness \
  -framework QuickLookUI -framework QuickLookThumbnailing -framework AppKit -framework WebKit \
  -o "$OUT/harness" \
  "$ROOT/Extension/PreviewViewController.swift" "$ROOT/Extension/DocumentRenderer.swift" \
  "$ROOT/scripts/harness/main.swift"
cp "$ROOT/Resources/marked.min.js" "$OUT/" 2>/dev/null || true
"$OUT/harness" "$@"
