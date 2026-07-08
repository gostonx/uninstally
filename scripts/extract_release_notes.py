#!/usr/bin/env python3
"""extract_release_notes.py — pull one version's notes out of CHANGELOG.md.

Emits the section for the given version as both Markdown (for the GitHub release
body) and minimal HTML (for the Sparkle appcast <description>). If the exact
version isn't found, falls back to the most recent "Unreleased" or first section
so a release never ships with empty notes.

Usage:
  extract_release_notes.py 1.4.0 --changelog CHANGELOG.md \
    --out-html notes.html --out-md notes.md
"""

from __future__ import annotations

import argparse
import html
import re


def extract_section(changelog: str, version: str) -> str:
    version = version.lstrip("v")
    lines = changelog.splitlines()
    start = None
    # Match "## [1.4.0]" or "## 1.4.0" (optionally with a date suffix).
    header = re.compile(rf"^##\s+\[?{re.escape(version)}\]?\b")
    for i, line in enumerate(lines):
        if header.match(line):
            start = i + 1
            break
    if start is None:
        # Fallback: first "## " section body.
        for i, line in enumerate(lines):
            if line.startswith("## "):
                start = i + 1
                break
    if start is None:
        return f"Uninstally {version}."

    body = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        body.append(line)
    text = "\n".join(body).strip()
    return text or f"Uninstally {version}."


def markdown_to_html(md: str) -> str:
    """A deliberately tiny Markdown subset -> HTML converter (headings, lists,
    bold/italic/code). No third-party dependency, safe-escaped."""
    out: list[str] = []
    in_list = False

    def close_list():
        nonlocal in_list
        if in_list:
            out.append("</ul>")
            in_list = False

    def inline(s: str) -> str:
        s = html.escape(s)
        s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
        s = re.sub(r"\*([^*]+)\*", r"<em>\1</em>", s)
        return s

    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            close_list()
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            close_list()
            level = min(len(m.group(1)) + 2, 6)  # #->h3 to keep it subtle
            out.append(f"<h{level}>{inline(m.group(2))}</h{level}>")
            continue
        m = re.match(r"^[-*]\s+(.*)$", line)
        if m:
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(m.group(1))}</li>")
            continue
        close_list()
        out.append(f"<p>{inline(line)}</p>")
    close_list()
    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("version")
    p.add_argument("--changelog", default="CHANGELOG.md")
    p.add_argument("--out-html", required=True)
    p.add_argument("--out-md", required=True)
    args = p.parse_args()

    with open(args.changelog, "r", encoding="utf-8") as f:
        changelog = f.read()

    md = extract_section(changelog, args.version)
    with open(args.out_md, "w", encoding="utf-8") as f:
        f.write(md + "\n")
    with open(args.out_html, "w", encoding="utf-8") as f:
        f.write(markdown_to_html(md) + "\n")

    print(f"Extracted notes for {args.version} ({len(md)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
