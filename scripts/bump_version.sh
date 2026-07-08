#!/usr/bin/env bash
#
# bump_version.sh — synchronise the app version across the whole project.
#
# Sets CFBundleShortVersionString (marketing version, e.g. 1.4.0) on both the app
# and the Finder extension, and sets CFBundleVersion (the monotonic build number
# Sparkle compares) for both. Keeping these identical everywhere is what allows
# "the git tag == GitHub release == appcast == website" invariant to hold.
#
# Usage:
#   scripts/bump_version.sh <marketing-version> [build-number]
#
# Examples:
#   scripts/bump_version.sh 1.4.0          # build number = auto (unix-ish counter)
#   scripts/bump_version.sh 1.4.0 42       # explicit build number
#
# In CI the marketing version is derived from the pushed tag (v1.4.0 -> 1.4.0) and
# the build number from the monotonically increasing GITHUB_RUN_NUMBER.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PLIST="$ROOT/Config/Uninstally-Info.plist"
EXT_PLIST="$ROOT/Config/UninstallyFinder-Info.plist"

MARKETING_VERSION="${1:?Usage: bump_version.sh <marketing-version> [build-number]}"
# Strip a leading "v" if a tag was passed by mistake.
MARKETING_VERSION="${MARKETING_VERSION#v}"

if [[ $# -ge 2 ]]; then
  BUILD_NUMBER="$2"
else
  # Derive a strictly-increasing build from the current one.
  CURRENT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST" 2>/dev/null || echo 0)"
  BUILD_NUMBER=$(( CURRENT + 1 ))
fi

for plist in "$APP_PLIST" "$EXT_PLIST"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$plist"
  echo "Updated $(basename "$plist"): $MARKETING_VERSION ($BUILD_NUMBER)"
done

# Expose the values to later CI steps.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "marketing_version=$MARKETING_VERSION"
    echo "build_number=$BUILD_NUMBER"
  } >> "$GITHUB_OUTPUT"
fi
