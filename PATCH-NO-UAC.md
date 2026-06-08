# IBS Mem Cleaner — no-UAC cleaning for a standard user (Win11 Pro)

This fork is patched so a **standard (non-admin) user** can run memory cleaning —
manual, hotkey, threshold auto-clean and interval auto-clean — with **no UAC
prompt**, provided the account has been granted two Windows privileges once by an
administrator.

This is a two-part change. **Both parts are required**; neither works alone.

---

## Part 1 — the code patch (already applied in this repo)

IBS Mem Cleaner gates all cleaning behind `_r_sys_iselevated()`. The kernel calls it
makes (`NtSetSystemInformation`) don't actually need a full admin token — they
need two specific privileges:

| Privilege | Constant | Used for |
|-----------|----------|----------|
| Profile single process | `SeProfileSingleProcessPrivilege` | working set, standby list, modified list, combine |
| Adjust memory quotas for a process | `SeIncreaseQuotaPrivilege` | system file cache |

The patch (`src/main.c`) replaces the elevation checks with a single runtime flag
`is_privileged`, set once in `_app_initialize`:

```c
status = _r_sys_setprocessprivilege (NtCurrentProcess (), privileges, ..., TRUE);
is_privileged = (status == STATUS_SUCCESS);   // TRUE only if the token HELD both
```

`NtAdjustPrivilegesToken` returns `STATUS_SUCCESS` only when **every** requested
privilege was present in the token (otherwise `STATUS_NOT_ALL_ASSIGNED`). So
`is_privileged` is TRUE when either the process is elevated *or* the standard-user
token was granted both rights via policy. All cleaning / auto-clean / hotkey /
UI-enable gates now key off `is_privileged`.

The two **skip-UAC** checks (the "Skip UAC warning" option) are intentionally left
on `_r_sys_iselevated()` — that feature is irrelevant in this model.

The app manifest is `asInvoker`, so it already launches with no UAC prompt; the
patch just makes it *use* the privileges the launching token carries.

---

## Part 2 — grant the two privileges (one-time, needs admin once)

You cannot skip this: Windows will not let a standard user perform these kernel
operations unless the account's logon token carries the rights. Granting them is
itself an admin action (by design).

### Option A — GUI (simplest on Win11 Pro)

1. Press <kbd>Win</kbd>+<kbd>R</kbd>, run **`secpol.msc`** (accept the UAC prompt — this is the one-time admin step).
2. Go to **Local Policies → User Rights Assignment**.
3. Double-click **"Profile single process"** → **Add User or Group** → add the
   standard user account → OK.
4. Double-click **"Adjust memory quotas for a process"** → **Add User or Group** →
   add the standard user account → OK.
   - ⚠️ Leave the existing entries (Administrators, LOCAL SERVICE, NETWORK SERVICE)
     in place — only **add** the user.
5. **Log off and back on** (or reboot) the standard user so the new token includes
   the privileges.

### Option B — scriptable (secedit), run from an elevated prompt

```bat
secedit /export /cfg "%TEMP%\sec.cfg" /areas USER_RIGHTS
```

Edit `%TEMP%\sec.cfg`: find (or add) these two lines and append the user's SID
(comma-separated, keep any existing values):

```
SeProfileSingleProcessPrivilege = *S-1-5-32-544,<USER_SID>
SeIncreaseQuotaPrivilege = *S-1-5-32-544,*S-1-5-19,*S-1-5-20,<USER_SID>
```

Get the SID with: `wmic useraccount where name='THEUSER' get sid`
(or `whoami /user` while logged in as that user). Then:

```bat
secedit /configure /db "%TEMP%\sec.sdb" /cfg "%TEMP%\sec.cfg" /areas USER_RIGHTS
```

Log off/on afterward.

> Note: on a domain machine these rights may be enforced by Group Policy and will
> revert on the next policy refresh — set them in the relevant GPO instead.

---

## Verify it worked

As the standard user, after re-login:

1. `whoami /priv` should list **SeProfileSingleProcessPrivilege** and
   **SeIncreaseQuotaPrivilege** (state "Disabled" is fine — IBS Mem Cleaner enables them).
2. Launch IBS Mem Cleaner normally (no "Run as administrator"). The **Clean** button has
   **no UAC shield**, and clicking it reports bytes freed instead of prompting.
3. Settings → Memory: the region checkboxes and auto-reduct controls are enabled.

If the Clean button still shows a shield / does nothing, the token didn't pick up
the rights — confirm step 1 and that you actually logged off and on.

---

## Operational notes

- **Disable auto-update** (Settings → "Check updates" off). henrypp's updater would
  replace this patched `ibsmemcleaner.exe` with the official build and undo Part 1.
  Re-apply the patch + rebuild if you ever update.
- **Standby / modified page list in auto-clean:** these are excluded from
  *automatic* cleaning by default (they can cause brief system stutter). To include
  them, enable Settings → Advanced → "Allow Standby lists … cleanup on autoreduct".
- This changes nothing about *which* operations run — only *who* is allowed to run
  them. Per-region selection, thresholds and intervals all behave as upstream.

---

## Build (on the Windows machine)

Requires the submodules and MSVC (this repo can't build on macOS):

```bat
git submodule update --init --recursive   :: fetches ..\routine and ..\builder
build.bat                                  :: -> calls ..\builder\build ibsmemcleaner 3.5.3 "IBS Mem Cleaner"
```

Output `ibsmemcleaner.exe` goes to `bin\`. For a quick test build you can also open
`ibsmemcleaner.sln` in Visual Studio (x64) and build.

> **Checkout folder name:** the builder derives the project path from the short
> name (`PROJECT_DIRECTORY = ../../ibsmemcleaner` in `build_package.py`). For
> `build.bat` packaging to find the project, the cloned repo folder must be named
> **`ibsmemcleaner`** (rename it after cloning, even though the GitHub repo is still
> `memreduct`). `build_vc.bat` alone (compile only) doesn't care about the folder name.

---

## Part 3 — installing without UAC

The stock henrypp installer (`builder/src/setup_script.nsi`) always prompts for
UAC, for three reasons:

| Line | Setting | Why it needs admin |
|------|---------|--------------------|
| 117 | `RequestExecutionLevel admin` | requests elevation outright |
| 114 | `InstallDir "$PROGRAMFILES64\..."` | Program Files is admin-only |
| 408+ | `WriteRegStr HKLM ...` | per-machine registry is admin-only |

This repo ships a **per-user installer** that avoids all three:
[`installer/setup_user.nsi`](installer/setup_user.nsi). It uses
`RequestExecutionLevel user`, installs to `%LOCALAPPDATA%\Programs\IBS Mem Cleaner`,
and writes only HKCU — so it installs, creates shortcuts, registers an Add/Remove
Programs entry, and (optionally) sets sign-in autostart, all with **no UAC prompt**.

Build it on Windows after building `ibsmemcleaner.exe` (needs [NSIS](https://nsis.sourceforge.io)):

```bat
cd installer
build_installer.bat            :: -> ibsmemcleaner-3.5.3-setup-user.exe
```

(or `makensis /DAPP_VERSION=3.5.3 /DAPP_FILES_DIR=..\bin setup_user.nsi`)

Edit `VER` / `FILES` at the top of `build_installer.bat` if your built exe lives
elsewhere.

### Honest caveats

- **SmartScreen, not UAC:** an unsigned exe from an unknown publisher may trigger
  "Windows protected your PC" on first run (Defender SmartScreen). That is a
  *reputation* warning, dismissible with **More info → Run anyway** — it is not an
  admin/UAC prompt. Authenticode-signing the installer + exe removes it over time;
  the GPG `.sig` henrypp ships is not Authenticode and does not affect SmartScreen.
- **The Part 2 privilege grant still requires admin once.** Installing without UAC
  and *cleaning* without UAC are separate problems — the per-user installer solves
  the first; only the one-time User Rights Assignment (Part 2) solves the second.
- **Portable alternative:** if you don't need shortcuts / uninstall entry, skip the
  installer entirely — drop the patched `ibsmemcleaner.exe` in a per-user folder with an
  empty `ibsmemcleaner.ini` next to it (portable mode). Zero install, zero UAC.
