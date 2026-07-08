# GitHub Actions Secrets

The release pipeline (`.github/workflows/release.yml`) needs the following
repository secrets. Add them under **Settings → Secrets and variables → Actions →
New repository secret** in `gostonx/uninstally`.

| Secret | Purpose |
|--------|---------|
| `BUILD_CERTIFICATE_BASE64` | Base64 of your **Developer ID Application** certificate exported as a `.p12`. |
| `CERTIFICATE_PASSWORD` | The password you set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string; used to create the temporary CI keychain. |
| `DEVELOPER_ID` | The full signing identity, e.g. `Developer ID Application: Your Name (TEAMID)`. |
| `TEAM_ID` | Your 10-character Apple Developer Team ID. |
| `APPLE_ID` | The Apple ID email used for notarization. |
| `APPLE_APP_PASSWORD` | An **app-specific password** for that Apple ID (not your login password). |
| `SPARKLE_PRIVATE_KEY` | The EdDSA private key produced by Sparkle's `generate_keys` (base64 string). |
| `SITE_REPO_TOKEN` | A fine-grained PAT with `contents: write` on `gostonx/codenta-site` (used to deploy the appcast + website). |
| `CLOUDFLARE_API_TOKEN` | *(optional)* Cloudflare token if deploying with `wrangler` instead of a site-repo commit. |
| `CLOUDFLARE_ACCOUNT_ID` | *(optional)* Cloudflare account ID. |
| `CLOUDFLARE_PROJECT_NAME` | *(optional)* Cloudflare Pages project name. |

---

## How to obtain each value

### `BUILD_CERTIFICATE_BASE64` + `CERTIFICATE_PASSWORD` + `DEVELOPER_ID` + `TEAM_ID`

1. In **Xcode → Settings → Accounts**, add your Apple ID and create a **Developer
   ID Application** certificate (or use **Keychain Access → Certificate
   Assistant**).
2. In **Keychain Access**, find *Developer ID Application: Your Name (TEAMID)*,
   right-click → **Export** → save as `cert.p12`, set a password
   (= `CERTIFICATE_PASSWORD`).
3. Base64-encode it:
   ```sh
   base64 -i cert.p12 | pbcopy      # paste into BUILD_CERTIFICATE_BASE64
   ```
4. `DEVELOPER_ID` is the exact certificate name; `TEAM_ID` is the value in
   parentheses (also shown at https://developer.apple.com/account under
   Membership).

### `KEYCHAIN_PASSWORD`

Any random string, e.g. `openssl rand -base64 24`.

### `APPLE_ID` + `APPLE_APP_PASSWORD`

1. `APPLE_ID` is your developer Apple ID email.
2. Create an app-specific password at https://appleid.apple.com → **Sign-In &
   Security → App-Specific Passwords**. Store it as `APPLE_APP_PASSWORD`.

### `SPARKLE_PRIVATE_KEY`

Generate the EdDSA key pair **once** with Sparkle's tool:

```sh
# Download Sparkle tools (same version as the SPM dependency), then:
./bin/generate_keys
```

This stores the private key in your login Keychain and prints the **public** key.

- Put the **public** key into `Config/Uninstally-Info.plist` under `SUPublicEDKey`
  (replacing the placeholder committed today).
- Export the **private** key for CI:
  ```sh
  ./bin/generate_keys -x sparkle_private_key.txt
  ```
  Paste the contents of `sparkle_private_key.txt` into the `SPARKLE_PRIVATE_KEY`
  secret, then delete the file. **Never commit the private key.**

### `SITE_REPO_TOKEN`

Create a **fine-grained personal access token** (https://github.com/settings/tokens)
scoped to `gostonx/codenta-site` with **Contents: Read and write**. This lets the
release job commit the regenerated `appcast.xml` and updated download links, which
triggers the Cloudflare Pages deploy.

### Cloudflare (optional direct deploy)

Only needed if you prefer `wrangler pages deploy` over committing to the site
repo. Create an API token with **Cloudflare Pages: Edit**; the account ID and
project name are shown in the Cloudflare dashboard.

---

## Security notes

- The public EdDSA key in the app and the private key in CI are a matched pair. If
  they don't match, Sparkle rejects every update (fail-closed) — see
  `docs/UPDATES.md` for rotation and revocation.
- Notarization credentials and signing certs are only ever exposed to the macOS
  runner during a tagged release and are removed from the keychain in the final
  `always()` step.
