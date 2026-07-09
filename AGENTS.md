# Uninstally

## Build
- After each logical step or group of related edits, run:
  `xcodebuild -project Uninstally.xcodeproj -scheme Uninstally -configuration Debug build 2>&1 | grep -E "error:|BUILD"`
- Do not proceed to the next step until the build succeeds.

## Architecture
- Business logic lives in Services/ or ViewModels/, never in Views/
- SwiftUI views should not perform file I/O, network calls, or direct UserDefaults manipulation
- String localization uses the `Localizable.xcstrings` catalog with `AppleLanguages` UserDefaults key

## Style
- No generic AI-style comments. Comments should explain non-obvious logic only.
- No marketing or privacy-assurance language in code comments.
- Avoid em-dash prose in documentation.
