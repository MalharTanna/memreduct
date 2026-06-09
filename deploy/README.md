# Deploying IBS Mem Cleaner to all PCs

For a fleet you do **not** use the per-user installer (that's for one machine, run
by the user). A centralized push runs as **SYSTEM**, so use the machine-wide
deployment here instead. One script does everything per PC.

## The deployment package

Bundle these four files in one folder (the release asset
`ibs-mem-cleaner-fleet-deploy.zip` already contains them):

| File | Purpose |
|------|---------|
| `deploy-fleet.cmd` | the entry point (run as SYSTEM/admin) |
| `ibsmemcleaner.exe` | the signed app (x64) |
| `ibs-codesign.cer` | public code-signing cert (for trust) |
| `grant-clean-privileges.ps1` | grants the no-UAC privileges |

`deploy-fleet.cmd` does, on each PC:
1. trusts the signing cert (Trusted Publishers + Root) → no SmartScreen, Seqrite trusts the publisher
2. installs `ibsmemcleaner.exe` to `%ProgramFiles%\IBS Mem Cleaner`
3. autostarts it for every user at logon (HKLM Run)
4. grants the two cleaning privileges to standard users (default: `BUILTIN\Users`)

**After it runs, users must log off/on (or reboot) once** for step 4 to take effect.

---

## Option A — Seqrite (no Active Directory needed)

1. In the Seqrite console open **Clients → Deployment → Software / Tools Deployment**
   (name varies by edition — anything that pushes a package and runs a command as SYSTEM).
2. Upload the unzipped package folder (all four files).
3. Set the run command to:
   ```
   deploy-fleet.cmd
   ```
   (or `deploy-fleet.cmd "CONTOSO\specificuser"` to grant rights to one account
   instead of all standard users.)
4. Target the endpoint group → deploy.
5. Schedule/announce a **reboot** (or have users sign out and back in).

Because Seqrite runs it as SYSTEM, there is no UAC during deployment, and step 1
makes Seqrite treat the app as a trusted publisher.

## Option B — Active Directory GPO

1. Copy the package to a share readable by domain computers, e.g.
   `\\server\deploy\ibsmemcleaner\`.
2. **Computer Configuration → Policies → Windows Settings → Scripts → Startup** →
   add `deploy-fleet.cmd` (with the share path as the script).
   *(Computer startup scripts run as SYSTEM.)*
3. Also import `ibs-codesign.cer` into **Trusted Publishers** + **Trusted Root**
   via Group Policy (Public Key Policies) if you prefer GPO-managed trust over the
   script's `certutil` step — either works.
4. Link the GPO to the OU with the target PCs. Apply on next reboot.

## Option C — one machine (manual)

Right-click `deploy-fleet.cmd` → **Run as administrator**, then log off/on.
(Or, for a single user who just wants it on their own PC without admin pushing it:
run the per-user `*-setup-user.exe` installer + `grant-privileges.cmd` — see
[PATCH-NO-UAC.md](../PATCH-NO-UAC.md).)

---

## Verify on an endpoint

As the standard user, after reboot:
- `whoami /priv` lists `SeProfileSingleProcessPrivilege` + `SeIncreaseQuotaPrivilege`
- IBS Mem Cleaner is running in the tray; **Clean memory** works with no UAC and no SmartScreen/Seqrite block.

## Notes

- Granting the rights to `BUILTIN\Users` means **every** standard user on the PC can
  clean memory. On an internally managed fleet that's the intent; to restrict it,
  pass a specific account/SID as the argument to `deploy-fleet.cmd`.
- The app stores per-user settings under `%APPDATA%\Henry++\IBS Mem Cleaner`.
- To **uninstall** fleet-wide: delete `%ProgramFiles%\IBS Mem Cleaner`, remove the
  HKLM Run value `IBS Mem Cleaner`, and (optionally) remove the privileges/cert.
