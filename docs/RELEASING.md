# Releasing Uninstally

Releasing is intentionally a three-step operation. Everything else — building,
testing, signing, notarizing, DMG creation, appcast generation, GitHub release,
and website deployment — is automated by `.github/workflows/release.yml`.

## Publish a stable release

```sh
# 1. Update the changelog (add a "## [1.4.0] — YYYY-MM-DD" section).
$EDITOR CHANGELOG.md

# 2. Commit.
git add CHANGELOG.md
git commit -m "Prepare 1.4.0"
git push

# 3. Tag and push the tag.
git tag v1.4.0
git push origin v1.4.0
```

That's it. Within a few minutes the pipeline will:

1. Derive the version (`1.4.0`) and build number (`GITHUB_RUN_NUMBER`) and write
   them into both Info.plists (`scripts/bump_version.sh`).
2. Build, run tests, archive, and export a Developer ID–signed app.
3. Build a professional DMG (`scripts/create_dmg.sh`), sign, **notarize**, and
   **staple** it, then verify with `codesign`/`spctl`/`stapler`.
4. Compute the SHA-256 and the **Sparkle EdDSA signature** of the DMG.
5. Extract release notes from `CHANGELOG.md`
   (`scripts/extract_release_notes.py`).
6. Publish the GitHub release with the DMG attached.
7. Regenerate `appcast.xml` (`scripts/make_appcast.py`), update the website
   download links + `uninstally-version.json`
   (`scripts/sync_website_version.py`), and commit them to `gostonx/codenta-site`,
   which Cloudflare Pages deploys to `https://codenta.us`.

Users then receive the update automatically via Sparkle (on next launch or within
24 hours), or immediately via **Settings → Updates → Check Now**.

## Publish a beta

Tag with a `-beta.N` suffix:

```sh
git tag v1.4.0-beta.1
git push origin v1.4.0-beta.1
```

The pipeline marks the GitHub release as a pre-release and adds
`<sparkle:channel>beta</sparkle:channel>` to the appcast item. Only users who
enable **Receive Beta Updates** (Settings → Updates) will be offered it.

## Publish a nightly

```sh
git tag v1.5.0-nightly.20260901
git push origin v1.5.0-nightly.20260901
```

Adds `<sparkle:channel>nightly</sparkle:channel>`. Reserved for users on the
nightly channel.

## Version invariants

The build number (`CFBundleVersion`) is what Sparkle compares, so it must be
**monotonically increasing**. The pipeline uses `GITHUB_RUN_NUMBER`, which always
increases. `CFBundleShortVersionString` is the human version from the tag. The
tag, GitHub release, appcast `sparkle:shortVersionString`, and website version are
all derived from the same tag, so they always match.

## Recovering from a failed release

Because the DMG is only published and the appcast only updated in the **final**
steps, a failure partway through leaves users unaffected (they keep seeing the
previous appcast).

- **Build/sign/notarize failed:** fix the issue, delete the tag, re-tag.
  ```sh
  git push --delete origin v1.4.0
  git tag -d v1.4.0
  # fix, commit, then re-tag
  git tag v1.4.0 && git push origin v1.4.0
  ```
- **Bad release already published to users:** publish a higher version that
  supersedes it (recommended), or edit `appcast.xml` in `codenta-site` to remove
  the bad `<item>` (users won't be offered it). Never reuse a build number.
- **Website didn't deploy:** re-run the "Deploy website" job, or manually run
  `scripts/sync_website_version.py` + copy `appcast.xml` into the site repo and
  push.

## Prerequisites (one-time)

- Configure all secrets in `docs/SECRETS.md`.
- Generate the Sparkle key pair and set `SUPublicEDKey` in
  `Config/Uninstally-Info.plist` (see `docs/UPDATES.md`).
- Ensure Cloudflare Pages is connected to `gostonx/codenta-site`.
