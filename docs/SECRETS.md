# GitHub Actions Secrets

Uninstally ships with a **free** release pipeline — no Apple Developer ID and no
notarization. Update security comes entirely from Sparkle's EdDSA signature, so
the only secrets you need are:

| Secret | Purpose |
|--------|---------|
| `SPARKLE_PRIVATE_KEY` | The EdDSA private key produced by Sparkle's `generate_keys` (base64 string). This signs each release; the app verifies it against `SUPublicEDKey`. |
| `SSH_DEPLOY_KEY` | The SSH private key of a **write deploy key** on `gostonx/codenta-site`. Used to deploy the regenerated `appcast.xml` + updated download links (Cloudflare Pages then builds automatically). |

Add them under **Settings → Secrets and variables → Actions → New repository
secret** in `gostonx/uninstally`.

---

## `SPARKLE_PRIVATE_KEY`

Generate the EdDSA key pair **once** (this is free and requires no Apple account):

```sh
# Download Sparkle's tools (same 2.x version as the SPM dependency), then:
./bin/generate_keys
```

`generate_keys` stores the private key in your login Keychain and prints the
**public** key.

1. Put the **public** key into `Config/Uninstally-Info.plist` under
   `SUPublicEDKey`, replacing the placeholder committed today.
2. Export the **private** key for CI and paste it into the `SPARKLE_PRIVATE_KEY`
   secret, then delete the file:
   ```sh
   ./bin/generate_keys -x sparkle_private_key.txt
   # copy the contents into the secret, then:
   rm sparkle_private_key.txt
   ```

**Never commit the private key.** The public key in the app and the private key in
CI are a matched pair — if they don't match, Sparkle rejects every update
(fail-closed). See `docs/UPDATES.md` for rotation and revocation.

## `SSH_DEPLOY_KEY`

An SSH key pair whose **public** half is registered as a *write* **deploy key** on
`gostonx/codenta-site`, and whose **private** half is this secret. The release job
checks out the site repo over SSH and pushes the regenerated `appcast.xml` +
updated download links, which triggers the Cloudflare Pages deploy of
`https://codenta.us`.

To rotate it:

```sh
ssh-keygen -t ed25519 -N "" -C "uninstally-release-deploy" -f deploy
gh api -X POST repos/gostonx/codenta-site/keys -f title="uninstally-release-deploy" \
  -f key="$(cat deploy.pub)" -F read_only=false
gh secret set SSH_DEPLOY_KEY -R gostonx/uninstally < deploy
rm deploy deploy.pub
```

### Optional: direct Cloudflare deploy

If you ever prefer `wrangler pages deploy` over committing to the site repo,
you'd add `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and
`CLOUDFLARE_PROJECT_NAME`. The default pipeline does **not** use these.

---

## Why no Apple secrets?

A Developer ID + notarization only affect the **first manual download** (Gatekeeper
shows an "unidentified developer" prompt once). They are **not** required for
Sparkle's auto-update: Sparkle verifies updates with EdDSA and strips the
quarantine flag from the updates it installs, so ongoing updates are seamless. See
`docs/UPDATES.md` for the full model and how to reduce first-install friction
(Homebrew / right-click → Open).
