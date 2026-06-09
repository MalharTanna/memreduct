# Fleet trust — IBS Mem Cleaner code-signing cert

`ibs-codesign.cer` is the **public** half of the certificate that signs
IBS Mem Cleaner in CI. It is safe to distribute (no private key). Installing it
into a machine's **Trusted Publishers** + **Trusted Root** stores makes Windows
and Seqrite trust the signed binaries — no SmartScreen prompt, no AV behaviour
flag.

The private key lives only as the GitHub Actions secret `CODE_SIGN_PFX_BASE64`
(write-only). The CI build signs with it automatically.

## Deploy to one machine

Right-click `install-cert.cmd` → **Run as administrator**.

## Deploy to the fleet

**Seqrite** — push `install-cert.cmd` + `ibs-codesign.cer` together via Seqrite's
software/script deployment (runs as SYSTEM, so it's silent), or run on each
endpoint:
```cmd
certutil -addstore -f "TrustedPublisher" ibs-codesign.cer
certutil -addstore -f "Root" ibs-codesign.cer
```

**Active Directory GPO** — Computer Configuration → Policies → Windows Settings →
Security Settings → Public Key Policies → import `ibs-codesign.cer` into both
**Trusted Publishers** and **Trusted Root Certification Authorities**.

## Rotating the certificate

The committed `.cer` is tied to the current signing key. If you ever regenerate
the cert (new key — e.g. via `tools/make-signing-cert.ps1`, or if the secret is
lost), you must:
1. update the `CODE_SIGN_PFX_BASE64` / `CODE_SIGN_PASSWORD` secrets, and
2. replace this `ibs-codesign.cer` and redeploy it to the fleet.

Current cert: `CN=Infinity Business Services`, Code Signing EKU, valid to 2031.
