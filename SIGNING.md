# Signing & antivirus trust (Seqrite / SmartScreen)

IBS Mem Cleaner manipulates system memory through undocumented Native API
(`NtSetSystemInformation`). Unsigned, that behaviour is exactly what Microsoft
SmartScreen and AV behaviour engines (Seqrite DNAScan) flag. **Code-signing the
binary and trusting the certificate fleet-wide is the durable fix** — it removes
the SmartScreen warning and stops most AV behaviour detections, without
maintaining per-endpoint exclusions.

Because IBS controls its own endpoints (managed via Seqrite), you do **not** need
a paid public-CA certificate — a **self-signed org certificate trusted on your
machines** is enough.

---

## 1. Create the org signing certificate (once)

On a Windows machine, run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\make-signing-cert.ps1
```

It produces:

| File | Use | Secret? |
|------|-----|---------|
| `ibs-codesign.pfx` | private key + cert (for CI) | **YES — keep secret** |
| `ibs-codesign.pfx.b64.txt` | base64 of the .pfx | paste as a CI secret |
| `ibs-codesign.cer` | public cert | deploy to endpoints (not secret) |

The private key never leaves your machine except as the password-protected `.pfx`
you choose to upload.

## 2. Turn on signing in CI

In the GitHub repo: **Settings → Secrets and variables → Actions → New repository
secret**, add:

- `CODE_SIGN_PFX_BASE64` = the contents of `ibs-codesign.pfx.b64.txt`
- `CODE_SIGN_PASSWORD` = the password you chose

That's it. The build's signing steps are **secret-gated** — once the secrets exist,
every build signs `ibsmemcleaner.exe` **and** the installer (SHA-256 + RFC-3161
timestamp). With no secrets, the build runs exactly as before (unsigned).

## 3. Trust the certificate on the fleet

A self-signed signature is only trusted where its public cert is installed. Deploy
`ibs-codesign.cer` to your endpoints' **Trusted Publishers** *and* **Trusted Root
Certification Authorities** (LocalMachine store):

**Via Group Policy (AD):**
Computer Configuration → Policies → Windows Settings → Security Settings → Public
Key Policies → import `ibs-codesign.cer` into **Trusted Publishers** and **Trusted
Root Certification Authorities**.

**Via Seqrite (no AD):** use Seqrite's software/script deployment to run on each
endpoint:
```cmd
certutil -addstore -f "TrustedPublisher" ibs-codesign.cer
certutil -addstore -f "Root" ibs-codesign.cer
```

After that, the signed exe/installer launch with no SmartScreen prompt and Seqrite
treats it as a trusted publisher.

---

## Stopgap: Seqrite false-positive submission

Until signing + fleet trust is in place (or if a specific Seqrite engine still
flags it), submit the binary to Quick Heal / Seqrite as a false positive so they
allowlist it at the vendor level. Upload `ibsmemcleaner.exe` to Seqrite's
false-positive / sample submission portal (or email your Seqrite support contact)
with this text:

> **Subject:** False-positive allowlist request — IBS Mem Cleaner (internal IT utility)
>
> We are Infinity Business Services. IBS Mem Cleaner is an internally developed,
> internally distributed Windows memory-cleaning utility (a fork of the
> open-source Mem Reduct by Henry++, GPL-3.0). It uses the documented-but-native
> Windows memory APIs (`NtSetSystemInformation`) to release working sets and
> standby/cache memory — the same technique as the original Mem Reduct.
>
> Seqrite Endpoint Security flags/quarantines it on our managed endpoints. It is
> not malware and is deployed only on our own machines. Please review and
> allowlist it.
>
> - File: `ibsmemcleaner.exe`
> - SHA-256: `<paste current hash>`
> - Installer: `ibsmemcleaner-<ver>-setup-user.exe`, SHA-256 `<paste current hash>`
> - Source: https://github.com/MalharTanna/memreduct
> - Contact: <your IBS support email>

> **Note:** the SHA-256 changes on every rebuild, so vendor-level hash allowlisting
> is only a stopgap. Signing (above) is the scalable answer — Seqrite can then
> allowlist by **publisher/certificate** instead of by hash.

---

## Why not just exclude it in Seqrite?

Per-endpoint path/hash exclusions work but don't scale: the install path is
per-user (`%LOCALAPPDATA%`) and the hash changes every build. A trusted signature
is publisher-based, so it survives rebuilds and applies fleet-wide automatically.
