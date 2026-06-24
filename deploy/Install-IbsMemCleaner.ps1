# ============================================================================
# IBS Mem Cleaner - one-shot deployment. RMM-safe (Action1, GPO, or an elevated
# PowerShell). Runs as SYSTEM/Administrator. NO param() block and no $PSScriptRoot
# use, so it survives RMM tools that wrap/inline the script.
#
# Re-runnable: it ALWAYS reinstalls (stops any running instance, re-downloads,
# overwrites). Each run leaves the machine in the correct end state.
#
# It does, machine-wide:
#   1. trusts the embedded code-signing cert  -> no SmartScreen, Seqrite trusts it
#   2. (re)installs ibsmemcleaner.exe + the clean/log wrapper to %ProgramFiles%
#   3. autostarts the tray app for every user at logon (HKLM Run)
#   4. grants the no-UAC cleaning privileges to standard users
#   5. registers a SYSTEM task that cleans + logs every N minutes (guaranteed,
#      no dependency on the per-user privilege grant)
#
# Cleaning log (for IT admins):  C:\ProgramData\IBS Mem Cleaner\clean-log.csv
#   one row per clean (timestamp, host, RAM% before/after, MB freed),
#   rolling LAST 15 DAYS.
# ============================================================================
$ErrorActionPreference = 'Stop'

# ===== settings (edit these if you want) ====================================
$Grantee        = 'S-1-5-32-545'   # BUILTIN\Users = all local standard users
$ExePath        = ''               # optional: local ibsmemcleaner.exe (else it downloads)
$NoAutostart    = $false           # $true to skip the per-user tray autostart
$IntervalMin    = 10               # SYSTEM auto-clean interval (minutes)
$LogRetainDays  = 15               # how many days of clean-log to keep
# ============================================================================

$Version    = '3.5.3'
$ExeUrl     = "https://github.com/MalharTanna/memreduct/releases/download/v$Version-ibs/ibsmemcleaner-$Version-x64.exe"
$InstallDir = Join-Path $env:ProgramFiles 'IBS Mem Cleaner'
$Wrapper    = Join-Path $InstallDir 'clean-and-log.ps1'
$TaskName   = 'IBS Mem Cleaner AutoClean'
$Privileges = @('SeProfileSingleProcessPrivilege', 'SeIncreaseQuotaPrivilege')

# Public code-signing cert (DER, base64). Safe to embed - no private key.
$CertB64 = 'MIIEeTCCAuGgAwIBAgIUMWX3kNYkURIajjEee2mASZe6BCswDQYJKoZIhvcNAQELBQAwSjEjMCEGA1UEAwwaSW5maW5pdHkgQnVzaW5lc3MgU2VydmljZXMxIzAhBgNVBAoMGkluZmluaXR5IEJ1c2luZXNzIFNlcnZpY2VzMB4XDTI2MDYwOTA2NDkwMFoXDTMxMDYwOTA2NDkwMFowSjEjMCEGA1UEAwwaSW5maW5pdHkgQnVzaW5lc3MgU2VydmljZXMxIzAhBgNVBAoMGkluZmluaXR5IEJ1c2luZXNzIFNlcnZpY2VzMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAq0VQ6l87ACLY9nq+SzLfFBNLTIjmg7y0hn/IKQ9OKcSCG0V6TfarHB4MpN8YRLnzj2YUJvmmqvzL8qS+Nnyv3vaEgDxJoxT7YvkRKMjYIwzHw2BwLt+mrkoiqDJ/sfMr/S2zhsbeSy7yxHTGrUgDCVqlP3BNaW3HBl9n4pgGAaXuZ3aZy8EY2EEbEPNc/AaSaHyp2ZQonDwfYU9InE3zxONWUqeZhFz2nMU3QD69i7aZKJ1Q+nkd0x7N1g1blu76pJcKDB0rYBt9Ji9S/3yavPwITOGnUFpfzegufgWpT5VNT1cDapbcL+a2fwJFixdR8fiZLcXGEo9g5Anab2PawRqjafoVqCcH+EBcaTUCsyitKo8MCnSDGcxSmvjJ2mUwtP5eGwwhatIkEblN3t7y7D/DCpSNJGRYTUR0Ot2jmhM8EX0JqTvT3hlG3cixi4PxPHRP3CVvG9PeZ0MFrDDJ8Uaeba9urusX4cwxPuqy+a6lkEGXvJ6GuzXd5xqObrcbAgMBAAGjVzBVMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQjgryMaxeshBJT3opzCYLpe2ptVTANBgkqhkiG9w0BAQsFAAOCAYEAl6r542XplcsJ4N1QgTy0katpY/2U0A4MMA0oFhD/GxfyMocaQ5Hp3ZLKSTS85douFrZb6JTBYfY+TMK0lATVr0H0RVJDDBykmBeJsfxhv8z9sKBGnY8EA6avhoP1zwtOZkydJD2zi/I/iEUTghy3VdrgFdkiE6Ob/rOQqLEqf1HeyevFqfjuX7l64Qheog65kTZuP9xT3U3agc9zzInauwLl6XD4ly3vsiU/tmnJY680CFsl4QprThlHDPmhbkqMVsVIwuQ6/u2P+q8wN/nkfJH/rlQfYAadtu1RkszY5cmoL4oODEkvgWWggr+69rc5GD17jJAtgpl0XoNGVjofmsaWauRChjtWysd08JiOlGIJ0vnvx0NGTTIw62PtUMEp/T6VJUMct/TukXm0qFBc2nbVrkdRdENw5lLyJYByHqslfU3IyDz6vVmJd8oskVO56aDY4WkoPskbLH/OIKf19e5upYOZD6TO6GtA73kj+ec9AwImKYt4SMvQPSUhHqVS'

# require elevation (Action1 / GPO run as SYSTEM = elevated)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Must run as Administrator/SYSTEM (open an elevated PowerShell, or push via Action1/GPO)."
}

function Step($n, $m) { Write-Host "[$n/5] $m" -ForegroundColor Cyan }

# ---- 1. trust the certificate ---------------------------------------------
Step 1 "Trusting code-signing certificate..."
$cer = Join-Path $env:TEMP 'ibs-codesign.cer'
[IO.File]::WriteAllBytes($cer, [Convert]::FromBase64String($CertB64))
certutil -addstore -f "TrustedPublisher" $cer | Out-Null
certutil -addstore -f "Root"             $cer | Out-Null
Remove-Item $cer -Force

# ---- 2. (re)install the exe + the clean/log wrapper ------------------------
Step 2 "Installing app to $InstallDir (reinstall every run)..."
# Delete the task FIRST so it can't relaunch the exe mid-update, then force-kill
# any running instance. cmd /c swallows "no such task / no process" cleanly so
# they don't surface as errors under $ErrorActionPreference='Stop'.
foreach ($tn in @($TaskName, "$TaskName (SYSTEM)")) {
    cmd /c "schtasks /Delete /TN ""$tn"" /F >nul 2>&1"
}
cmd /c "taskkill /F /IM ibsmemcleaner.exe /T >nul 2>&1"
Start-Sleep -Seconds 1

if (-not $ExePath -or -not (Test-Path $ExePath)) {
    Write-Host "      downloading signed exe..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ExePath = Join-Path $env:TEMP 'ibsmemcleaner.exe'
    Invoke-WebRequest -Uri $ExeUrl -OutFile $ExePath -UseBasicParsing
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# overwrite with retry - handles transient locks (running exe, AV scan, handle release)
$dest = Join-Path $InstallDir 'ibsmemcleaner.exe'
$copied = $false
for ($i = 1; $i -le 10 -and -not $copied; $i++) {
    try {
        Copy-Item $ExePath $dest -Force
        $copied = $true
    } catch {
        cmd /c "taskkill /F /IM ibsmemcleaner.exe /T >nul 2>&1"
        Start-Sleep -Milliseconds 800
    }
}
if (-not $copied) { throw "Could not overwrite $dest - still locked after 10 attempts." }

# write the clean+log wrapper that the SYSTEM task runs each cycle
$wrapperBody = @'
# IBS Mem Cleaner - clean + log (run as SYSTEM by the scheduled task).
$ErrorActionPreference = 'SilentlyContinue'
$exe    = Join-Path $PSScriptRoot 'ibsmemcleaner.exe'
$logDir = 'C:\ProgramData\IBS Mem Cleaner'
$log    = Join-Path $logDir 'clean-log.csv'
$retain = 15

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not (Test-Path $log)) { 'Timestamp,Host,UsedPctBefore,UsedPctAfter,FreedMB' | Set-Content -Encoding UTF8 $log }

$os1   = Get-CimInstance Win32_OperatingSystem
$total = [double]$os1.TotalVisibleMemorySize
$free1 = [double]$os1.FreePhysicalMemory

& $exe -clean:full
Start-Sleep -Seconds 3

$os2   = Get-CimInstance Win32_OperatingSystem
$free2 = [double]$os2.FreePhysicalMemory

$usedBefore = [math]::Round((($total - $free1) / $total) * 100, 1)
$usedAfter  = [math]::Round((($total - $free2) / $total) * 100, 1)
$freedMB    = [math]::Round(($free2 - $free1) / 1024, 1)
$ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
"$ts,$env:COMPUTERNAME,$usedBefore,$usedAfter,$freedMB" | Add-Content -Encoding UTF8 $log

# keep only the last N days
try {
    $cut  = (Get-Date).AddDays(-$retain)
    $all  = @(Get-Content $log)
    if ($all.Count -gt 1) {
        $head = $all[0]
        $kept = $all | Select-Object -Skip 1 | Where-Object {
            $d = [datetime]::MinValue
            if ([datetime]::TryParse(($_ -split ',')[0], [ref]$d)) { $d -ge $cut } else { $true }
        }
        @($head) + @($kept) | Set-Content -Encoding UTF8 $log
    }
} catch { }
'@
Set-Content -Path $Wrapper -Value $wrapperBody -Encoding UTF8 -Force

# ---- 3. autostart the tray app for all users ------------------------------
if ($NoAutostart) {
    Step 3 "Autostart skipped."
} else {
    Step 3 "Enabling tray autostart for all users..."
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'IBS Mem Cleaner' -PropertyType String -Value "`"$InstallDir\ibsmemcleaner.exe`"" -Force | Out-Null
}

# ---- 4. grant the cleaning privileges -------------------------------------
Step 4 "Granting no-UAC cleaning privileges to $Grantee ..."

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LsaHelper {
    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)]
    public struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern uint LsaOpenPolicy(ref LSA_UNICODE_STRING SystemName, ref LSA_OBJECT_ATTRIBUTES ObjectAttributes, uint DesiredAccess, out IntPtr PolicyHandle);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern uint LsaAddAccountRights(IntPtr PolicyHandle, byte[] AccountSid, LSA_UNICODE_STRING[] UserRights, uint CountOfRights);
    [DllImport("advapi32.dll")] public static extern uint LsaClose(IntPtr PolicyHandle);
    [DllImport("advapi32.dll")] public static extern int LsaNtStatusToWinError(uint Status);
    public static LSA_UNICODE_STRING Str(string s) {
        LSA_UNICODE_STRING u = new LSA_UNICODE_STRING();
        u.Buffer = Marshal.StringToHGlobalUni(s);
        u.Length = (ushort)(s.Length * 2);
        u.MaximumLength = (ushort)(s.Length * 2 + 2);
        return u;
    }
}
'@

if ($Grantee -match '^S-1-') {
    $sid = New-Object System.Security.Principal.SecurityIdentifier($Grantee)
} else {
    $sid = (New-Object System.Security.Principal.NTAccount($Grantee)).Translate([System.Security.Principal.SecurityIdentifier])
}
$sidBytes = New-Object byte[] $sid.BinaryLength
$sid.GetBinaryForm($sidBytes, 0)

$oa  = New-Object LsaHelper+LSA_OBJECT_ATTRIBUTES
$sys = New-Object LsaHelper+LSA_UNICODE_STRING
$h   = [IntPtr]::Zero
$st  = [LsaHelper]::LsaOpenPolicy([ref]$sys, [ref]$oa, 0x000F0FFF, [ref]$h)
if ($st -ne 0) { throw "LsaOpenPolicy failed (WinError $([LsaHelper]::LsaNtStatusToWinError($st)))" }
try {
    $rights = [LsaHelper+LSA_UNICODE_STRING[]]($Privileges | ForEach-Object { [LsaHelper]::Str($_) })
    $st = [LsaHelper]::LsaAddAccountRights($h, $sidBytes, $rights, $Privileges.Count)
    if ($st -ne 0) { throw "LsaAddAccountRights failed (WinError $([LsaHelper]::LsaNtStatusToWinError($st)))" }
} finally { [LsaHelper]::LsaClose($h) | Out-Null }

# ---- 5. SYSTEM task: clean + log every N min (guaranteed, no user dependency)
Step 5 "Registering SYSTEM clean+log task (every $IntervalMin min)..."
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Wrapper`""
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMin) -RepetitionDuration (New-TimeSpan -Days 3650)
$prin    = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $prin -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName   # clean once now

Write-Host ""
Write-Host "SUCCESS - IBS Mem Cleaner deployed/updated." -ForegroundColor Green
Write-Host "Auto-clean + logging via SYSTEM task every $IntervalMin min (works now, no reboot)." -ForegroundColor Green
Write-Host "Admin log: C:\ProgramData\IBS Mem Cleaner\clean-log.csv (rolling $LogRetainDays days)." -ForegroundColor Green
Write-Host "Manual in-app Clean needs the user to log off/on once (privilege grant)." -ForegroundColor Yellow
exit 0
