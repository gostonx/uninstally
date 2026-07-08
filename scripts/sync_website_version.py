#!/usr/bin/env python3
"""sync_website_version.py — keep the Codenta website in step with a release.

Given the release version and the DMG download URL, this updates the Uninstally
download links in the site's HTML and writes `uninstally-version.json` (mirroring
the existing orbita/quitty version files). The CI runs this against a checkout of
the `codenta-site` repository; committing the result triggers the site deploy.

Usage:
  sync_website_version.py --site-dir ./site \
    --version 1.4.0 \
    --url https://github.com/gostonx/uninstally/releases/download/v1.4.0/Uninstally.dmg \
    [--notes-file notes.md]
"""

import argparse
import json
import os
import re
from datetime import date

DMG_URL_RE = re.compile(
    r"https://(?:example\.com/uninstally\.dmg"
    r"|github\.com/gostonx/uninstally/releases/download/[^\"']+?/Uninstally\.dmg)"
)


def update_html(path: str, url: str) -> bool:
    if not os.path.exists(path):
        return False
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    new_text = DMG_URL_RE.sub(url, text)
    if new_text != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_text)
        return True
    return False


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--site-dir", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--url", required=True)
    p.add_argument("--notes-file")
    args = p.parse_args()

    version = args.version.lstrip("v")
    changed = []
    for name in ("index.html", "products.html"):
        if update_html(os.path.join(args.site_dir, name), args.url):
            changed.append(name)

    notes = ""
    if args.notes_file and os.path.exists(args.notes_file):
        with open(args.notes_file, "r", encoding="utf-8") as f:
            notes = f.read().strip()

    version_json = {
        "name": "Uninstally",
        "version": version,
        "url": args.url,
        "date": date.today().isoformat(),
        "notes": notes,
        "appcast": "https://codenta.us/appcast.xml",
    }
    out = os.path.join(args.site_dir, "uninstally-version.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(version_json, f, indent=2)
        f.write("\n")

    print(f"Updated download links in: {', '.join(changed) or 'none'}")
    print(f"Wrote {out} (version {version})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
