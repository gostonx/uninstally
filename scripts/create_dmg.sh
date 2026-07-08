#!/usr/bin/env bash
#
# create_dmg.sh — build a professional, notarizable DMG for Uninstally.
#
# Produces a compressed (UDZO) disk image with:
#   • the app bundle
#   • an /Applications shortcut for drag-to-install
#   • a retina background image with a guiding arrow
#   • fixed icon positions and a hidden toolbar/sidebar
#
# Requires `create-dmg` (https://github.com/create-dmg/create-dmg):
#   brew install create-dmg
#
# Usage:
#   scripts/create_dmg.sh <path-to-Uninstally.app> <output.dmg>
#
# The caller is responsible for code-signing the .app beforehand and for
# code-signing + notarizing the resulting DMG afterwards.

set -euo pipefail

APP_PATH="${1:?Usage: create_dmg.sh <app> <output.dmg>}"
OUTPUT_DMG="${2:?Usage: create_dmg.sh <app> <output.dmg>}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BG_1X="$ROOT/scripts/assets/dmg-background.png"
BG_2X="$ROOT/scripts/assets/dmg-background@2x.png"

# create-dmg wants a single background image; it will use the @2x automatically
# if a file named "<name>@2x.png" sits beside it.
cp "$BG_2X" "$(dirname "$BG_1X")/dmg-background@2x.png" 2>/dev/null || true

rm -f "$OUTPUT_DMG"

create-dmg \
  --volname "Uninstally" \
  --background "$BG_1X" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 120 \
  --icon "Uninstally.app" 160 200 \
  --hide-extension "Uninstally.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  --format UDZO \
  "$OUTPUT_DMG" \
  "$APP_PATH"

echo "Created $OUTPUT_DMG"
