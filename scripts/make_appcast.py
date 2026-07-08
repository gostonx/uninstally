#!/usr/bin/env python3
"""make_appcast.py — generate/merge a Sparkle appcast for Uninstally.

Sparkle reads a single feed (https://codenta.us/appcast.xml). This tool inserts a
new <item> for a freshly built release and preserves prior items so older clients
can still see the version history. Channels are supported: `stable` items carry no
<sparkle:channel>; `beta`/`nightly` items carry one so only opted-in users see
them.

The EdDSA signature and file length come from Sparkle's `sign_update` tool, which
the CI runs against the notarized DMG. Nothing here trusts anything unsigned.

Usage:
  make_appcast.py \
    --output appcast.xml \
    [--appcast existing_appcast.xml] \
    --version 42 \
    --short-version 1.4.0 \
    --url https://github.com/gostonx/uninstally/releases/download/v1.4.0/Uninstally.dmg \
    --length 12582912 \
    --signature <base64-edSignature> \
    --channel stable \
    --min-system 14.0 \
    --notes-file notes.html
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from datetime import datetime, timezone
from email.utils import format_datetime

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def build_item(args, pub_date: str, notes_html: str) -> str:
    channel_tag = ""
    if args.channel and args.channel != "stable":
        channel_tag = f"      <sparkle:channel>{html.escape(args.channel)}</sparkle:channel>\n"

    return (
        "    <item>\n"
        f"      <title>Version {html.escape(args.short_version)}</title>\n"
        f"      <pubDate>{pub_date}</pubDate>\n"
        f"      <sparkle:version>{html.escape(str(args.version))}</sparkle:version>\n"
        f"      <sparkle:shortVersionString>{html.escape(args.short_version)}</sparkle:shortVersionString>\n"
        f"      <sparkle:minimumSystemVersion>{html.escape(args.min_system)}</sparkle:minimumSystemVersion>\n"
        f"{channel_tag}"
        f"      <description><![CDATA[{notes_html}]]></description>\n"
        f'      <enclosure url="{html.escape(args.url, quote=True)}"\n'
        f'                 sparkle:version="{html.escape(str(args.version), quote=True)}"\n'
        f'                 sparkle:shortVersionString="{html.escape(args.short_version, quote=True)}"\n'
        f'                 length="{int(args.length)}"\n'
        f'                 type="application/octet-stream"\n'
        f'                 sparkle:edSignature="{html.escape(args.signature, quote=True)}" />\n'
        "    </item>"
    )


def existing_items(appcast_text: str) -> list[str]:
    return re.findall(r"[ \t]*<item>.*?</item>", appcast_text, flags=re.DOTALL)


def item_version(item: str) -> str | None:
    m = re.search(r"<sparkle:version>\s*([^<]+?)\s*</sparkle:version>", item)
    return m.group(1) if m else None


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--output", required=True)
    p.add_argument("--appcast", help="Existing appcast to merge into")
    p.add_argument("--version", required=True, help="CFBundleVersion (build number)")
    p.add_argument("--short-version", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--length", required=True, type=int)
    p.add_argument("--signature", required=True)
    p.add_argument("--channel", default="stable", choices=["stable", "beta", "nightly"])
    p.add_argument("--min-system", default="14.0")
    p.add_argument("--title", default="Uninstally")
    p.add_argument("--notes-file", help="HTML release notes")
    p.add_argument("--max-items", type=int, default=20)
    args = p.parse_args()

    # Security: only ever point at the official GitHub release download host.
    if not args.url.startswith("https://github.com/gostonx/uninstally/releases/download/"):
        print(f"Refusing untrusted enclosure URL: {args.url}", file=sys.stderr)
        return 2

    notes_html = ""
    if args.notes_file:
        with open(args.notes_file, "r", encoding="utf-8") as f:
            notes_html = f.read().strip()

    pub_date = format_datetime(datetime.now(timezone.utc))
    new_item = build_item(args, pub_date, notes_html)

    items = []
    if args.appcast:
        try:
            with open(args.appcast, "r", encoding="utf-8") as f:
                items = existing_items(f.read())
        except FileNotFoundError:
            items = []

    # Drop any prior item with the same build number, then prepend the new one.
    items = [it for it in items if item_version(it) != str(args.version)]
    items = [new_item] + items
    items = items[: args.max_items]

    body = "\n".join(items)
    feed = (
        '<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n'
        f'<rss version="2.0" xmlns:sparkle="{SPARKLE_NS}" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        "  <channel>\n"
        f"    <title>{html.escape(args.title)}</title>\n"
        "    <description>Most recent changes to Uninstally.</description>\n"
        "    <language>en</language>\n"
        f"    <link>https://codenta.us/appcast.xml</link>\n"
        f"{body}\n"
        "  </channel>\n"
        "</rss>\n"
    )

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(feed)
    print(f"Wrote {args.output} with {len(items)} item(s); newest = {args.short_version} (build {args.version})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
