#!/usr/bin/env python3
"""Generate the Localizable.xcstrings String Catalog for Uninstally.

Creates a seeded catalog with ~50 of the most prominent user-facing strings (each
already English‑translated) and nine other language columns set as "needs review"
with the English text as a fallback placeholder so translators later only need to
fill in values. Xcode will auto‑extract any remaining SwiftUI string literals
at build time, continuously growing this catalog.

Run: python3 scripts/make_xcstrings.py
"""

import json, os, sys

LANGS = [
    ("en", "English"),
    ("it", "Italian"),
    ("es", "Spanish"),
    ("fr", "French"),
    ("de", "German"),
    ("pt", "Portuguese"),
    ("ja", "Japanese"),
    ("ko", "Korean"),
    ("zh-Hans", "Chinese (Simplified)"),
    ("zh-Hant", "Chinese (Traditional)"),
]

# Manually curated strings covering all major surfaces.
STRINGS = {}
for i, s in enumerate([
    "Cancel", "Done", "Open", "Uninstall", "Proceed with Uninstall",
    "Delete Permanently", "Move to Trash",
    "Applications", "Favorites", "Collections", "Tools",
    "Leftover Scanner", "Homebrew", "Storage Insights", "Recently Uninstalled",
    "Customize Sidebar…", "Customize Settings…",
    "New Collection", "Rename…", "Delete Collection",
    "Settings", "General", "Updates", "Appearance", "Uninstall Settings",
    "Scanning", "Security", "Advanced", "About",
    "Uninstall Simulation", "This simulation has not deleted any files.",
    "Remove Selected", "Clear History",
    "Checking…", "Update available", "You're up to date",
    "Application", "Related Files", "Recoverable Storage",
    "User Files", "Administrator Files", "Shared Components",
    "Login Items", "Launch Agents", "Containers", "Preference Files",
    "Deletion Method", "Show icon in Dock", "Confirm",
    "Permanently Delete", "Remove From History", "Restore from Trash",
    "View Details", "Reveal Location",
]):
    key = f"_{i:03d}_{s.lower().replace(' ', '_').replace('.', '').replace('…', '')}"
    STRINGS[key] = s

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Uninstally",
    "Localizable.xcstrings",
)

TEMPLATE = {
    "sourceLanguage": "en",
    "strings": {},
    "version": "1.0",
}

for key, en_value in STRINGS.items():
    entry = {
        "extractionState": "manual",
        "localizations": {},
    }
    for code, name in LANGS:
        localization = {
            "stringUnit": {
                "state": "translated" if code == "en" else "needs_review",
                "value": en_value,
            }
        }
        entry["localizations"][code] = localization
    TEMPLATE["strings"][key] = entry


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(TEMPLATE, f, indent=2, ensure_ascii=False)
    print(f"Wrote {OUT} ({len(STRINGS)} strings, {len(LANGS)} languages)")


if __name__ == "__main__":
    main()
