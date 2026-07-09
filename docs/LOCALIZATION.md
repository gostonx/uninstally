# Localization

Uninstally uses Apple's modern **String Catalog** (`.xcstrings`) for all
user‑facing text. The infrastructure is fully built — translating into the ten
prepared languages requires no code changes, only filling in the translated values
in the catalog.

## Architecture

| Component | File | Role |
|-----------|------|------|
| String Catalog | `Uninstally/Localizable.xcstrings` | One catalog for **every** user‑facing string. Xcode automatically extracts SwiftUI literals (`Text("…")`, `Label("…")`, `navigationTitle("…")`, etc.) at build time; new strings appear in the catalog with zero manual work. |
| Language Manager | `Services/LanguageManager.swift` | Tracks the current language override (via `AppleLanguages` `UserDefaults`), lists the 10 supported languages, and handles the restart required to apply a switch. |
| Settings → Language | `Views/SettingsSections.swift` | A native picker showing every language in its own name (e.g. "日本語"), plus a checkmark on the active one. Selecting a different language presents a "Restart Required" alert with **Restart Now** and **Later** options. |
| Project config | `project.pbxproj` (`knownRegions`) + `Config/Uninstally-Info.plist` (`CFBundleLocalizations`) | Declares the ten supported languages so macOS and Xcode recognise them. |

## Supported languages

| Code | Native name | Translation status |
|------|-------------|--------------------|
| `en` | English | ✓ Complete (source language) |
| `it` | Italiano | Placeholder (needs translation) |
| `es` | Español | Placeholder |
| `fr` | Français | Placeholder |
| `de` | Deutsch | Placeholder |
| `pt` | Português | Placeholder |
| `ja` | 日本語 | Placeholder |
| `ko` | 한국어 | Placeholder |
| `zh-Hans` | 简体中文 | Placeholder |
| `zh-Hant` | 繁體中文 | Placeholder |

## How to add a new language

1. Open `Uninstally/Localizable.xcstrings` in Xcode.
2. Click the **+** at the top of the language column → choose the language.
3. Xcode creates the column. Fill in each string's translated value.
4. Add the new code to `knownRegions` in `project.pbxproj`, to
   `CFBundleLocalizations` in `Config/Uninstally-Info.plist`, and to
   `LanguageManager.supportedLanguages`.
5. Build — that's it. No other files change.

## How to translate existing English strings

1. Open `Uninstally/Localizable.xcstrings` in Xcode.
2. The catalog shows every extracted string and its language columns.
3. Fill in the cell for each language you want to translate.
4. Build and run to test the new translations.
5. Test pluralisation by searching for strings with `%@` format specifiers — use
   `stringsdict` inside the catalog if a string needs per‑language plural rules.

## How to add a brand‑new user‑facing string in code

Just use a SwiftUI literal — it's automatically extracted:

```swift
Text("New uninstall simulation running")
Button("Scan Leftovers") { ... }
.navigationTitle("Recently Deleted")
```

Xcode adds it to the catalog on the next build. If you need to localise a
`String` variable (e.g. inside `NotificationService`), wrap it:

```swift
String(localized: "Application moved to Trash")
```

The key must match the English source. Non‑SwiftUI strings that use
`String(format:)` with plurals should have a companion `stringsdict` entry.

## How to test a localised build

1. Edit the current scheme (**⌘<**) → Options → App Language → pick the target
   language.
2. Run the app — it uses the selected language without changing the system global.
3. To test the in‑app language switcher: go to **Settings → Language**, pick a
   language, **Restart Now** — the app re‑launches in the new language.

## How dynamic localisation works

- **SwiftUI literals** (`Text`, `Label`, `navigationTitle`, `Button`, `searchable`
  prompts, `.help`, `.accessibilityLabel`, `.confirmationDialog` titles/messages)
  all use `LocalizedStringKey` automatically — zero effort.
- **`String(localized:)`** for programmatic strings (notifications, alerts created
  in code, Finder menus).
- **Dates, times, numbers, storage sizes** are passed through the system formatters
  (`DateFormatter`, `ByteCountFormatter`, etc.) respeecting the current locale.
- **Plurals** — SwiftUI's automatic string extraction handles simple plurals;
  complex cases are covered by `stringsdict` entries inside the `.xcstrings`
  catalog. See the "Photo" example in Apple's sample catalogs.

## Fallback

If the user's chosen language has no translation for a string, macOS's standard
localisation fallback chain applies: region‑matched variant → development language
(`en`) → base → the string literal itself. The app never shows empty text.
