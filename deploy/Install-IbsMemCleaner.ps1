<#
.SYNOPSIS
  One-shot installer for IBS Mem Cleaner on a single PC or across a fleet.

.DESCRIPTION
  Run elevated (it self-elevates if you double-click / right-click Run with
  PowerShell). When pushed by Seqrite or a GPO computer-startup script it already
  runs as SYSTEM, so it just proceeds. It performs, machine-wide:

    1. Trusts the IBS code-signing certificate (embedded below) -> no SmartScreen,
       Seqrite trusts the publisher.
    2. Installs ibsmemcleaner.exe to %ProgramFiles%\IBS Mem Cleaner
       (uses -ExePath, or ibsmemcleaner.exe next to this script, else downloads
       the signed exe from the GitHub release).
    3. Autostarts it for every user at logon (HKLM Run).
    4. Grants the no-UAC memory-cleaning privileges (SeProfileSingleProcess +
       SeIncreaseQuota) to standard users.

  Users must log off/on (or reboot) ONCE afterwards for step 4 to take effect.

.PARAMETER Grantee
  Account or SID that receives the cleaning privileges.
  Default S-1-5-32-545 (BUILTIN\Users = all standard users). Pass e.g.
  "CONTOSO\jdoe" to restrict it.

.PARAMETER ExePath
  Path to a local ibsmemcleaner.exe to install (skips the download).

.PARAMETER NoAutostart
  Do not add the HKLM Run autostart entry.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Install-IbsMemCleaner.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Install-IbsMemCleaner.ps1 -Grantee "CONTOSO\jdoe"
#>
[CmdletBinding()]
param(
    [string]$Grantee = 'S-1-5-32-545',
    [string]$ExePath,
    [switch]$NoAutostart
)

$ErrorActionPreference = 'Stop'

# ---- config ----------------------------------------------------------------
$Version    = '3.5.3'
$ReleaseTag = "v$Version-ibs"
$ExeUrl     = "https://github.com/MalharTanna/memreduct/releases/download/$ReleaseTag/ibsmemcleaner-$Version-x64.exe"
$InstallDir = Join-Path $env:ProgramFiles 'IBS Mem Cleaner'
$Privileges = @('SeProfileSingleProcessPrivilege', 'SeIncreaseQuotaPrivilege')

# Public code-signing cert (DER, base64). Safe to embed - no private key.
$CertB64 = 'MIIEeTCCAuGgAwIBAgIUMWX3kNYkURIajjEee2mASZe6BCswDQYJKoZIhvcNAQELBQAwSjEjMCEGA1UEAwwaSW5maW5pdHkgQnVzaW5lc3MgU2VydmljZXMxIzAhBgNVBAoMGkluZmluaXR5IEJ1c2luZXNzIFNlcnZpY2VzMB4XDTI2MDYwOTA2NDkwMFoXDTMxMDYwOTA2NDkwMFowSjEjMCEGA1UEAwwaSW5maW5pdHkgQnVzaW5lc3MgU2VydmljZXMxIzAhBgNVBAoMGkluZmluaXR5IEJ1c2luZXNzIFNlcnZpY2VzMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAq0VQ6l87ACLY9nq+SzLfFBNLTIjmg7y0hn/IKQ9OKcSCG0V6TfarHB4MpN8YRLnzj2YUJvmmqvzL8qS+Nnyv3vaEgDxJoxT7YvkRKMjYIwzHw2BwLt+mrkoiqDJ/sfMr/S2zhsbeSy7yxHTGrUgDCVqlP3BNaW3HBl9n4pgGAaXuZ3aZy8EY2EEbEPNc/AaSaHyp2ZQonDwfYU9InE3zxONWUqeZhFz2nMU3QD69i7aZKJ1Q+nkd0x7N1g1blu76pJcKDB0rYBt9Ji9S/3yavPwITOGnUFpfzegufgWpT5VNT1cDapbcL+a2fwJFixdR8fiZLcXGEo9g5Anab2PawRqjafoVqCcH+EBcaTUCsyitKo8MCnSDGcxSmvjJ2mUwtP5eGwwhatIkEblN3t7y7D/DCpSNJGRYTUR0Ot2jmhM8EX0JqTvT3hlG3cixi4PxPHRP3CVvG9PeZ0MFrDDJ8Uaeba9urusX4cwxPuqy+a6lkEGXvJ6GuzXd5xqObrcbAgMBAAGjVzBVMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQjgryMaxeshBJT3opzCYLpe2ptVTANBgkqhkiG9w0BAQsFAAOCAYEAl6r542XplcsJ4N1QgTy0katpY/2U0A4MMA0oFhD/GxfyMocaQ5Hp3ZLKSTS85douFrZb6JTBYfY+TMK0lATVr0H0RVJDDBykmBeJsfxhv8z9sKBGnY8EA6avhoP1zwtOZkydJD2zi/I/iEUTghy3VdrgFdkiE6Ob/rOQqLEqf1HeyevFqfjuX7l64Qheog65kTZuP9xT3U3agc9zzInauwLl6XD4ly3vsiU/tmnJY680CFsl4QprThlHDPmhbkqMVsVIwuQ6/u2P+q8wN/nkfJH/rlQfYAadtu1RkszY5cmoL4oODEkvgWWggr+69rc5GD17jJAtgpl0XoNGVjofmsaWauRChjtWysd08JiOlGIJ0vnvx0NGTTIw62PtUMEp/T6VJUMct/TukXm0qFBc2nbVrkdRdENw5lLyJYByHqslfU3IyDz6vVmJd8oskVO56aDY4WkoPskbLH/OIKf19e5upYOZD6TO6GtA73kj+ec9AwImKYt4SMvQPSUhHqVS'

# ---- self-elevate ----------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Elevating..."
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Grantee',"`"$Grantee`"")
    if ($ExePath)     { $a += @('-ExePath',"`"$ExePath`"") }
    if ($NoAutostart) { $a += '-NoAutostart' }
    Start-Process powershell -Verb RunAs -ArgumentList $a
    return
}

function Step($n, $msg) { Write-Host "[$n/4] $msg" -ForegroundColor Cyan }

# ---- 1. trust the certificate ---------------------------------------------
Step 1 "Trusting code-signing certificate..."
$cerPath = Join-Path $env:TEMP 'ibs-codesign.cer'
[IO.File]::WriteAllBytes($cerPath, [Convert]::FromBase64String($CertB64))
certutil -addstore -f "TrustedPublisher" $cerPath | Out-Null
certutil -addstore -f "Root"             $cerPath | Out-Null
Remove-Item $cerPath -Force

# ---- 2. install the exe ----------------------------------------------------
Step 2 "Installing app to `"$InstallDir`"..."
if (-not $ExePath) {
    $local = Join-Path $PSScriptRoot 'ibsmemcleaner.exe'
    if (Test-Path $local) { $ExePath = $local }
}
if (-not $ExePath -or -not (Test-Path $ExePath)) {
    Write-Host "      downloading signed exe from $ExeUrl"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ExePath = Join-Path $env:TEMP 'ibsmemcleaner.exe'
    Invoke-WebRequest -Uri $ExeUrl -OutFile $ExePath -UseBasicParsing
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item $ExePath (Join-Path $InstallDir 'ibsmemcleaner.exe') -Force

# ---- 3. autostart for all users -------------------------------------------
if ($NoAutostart) {
    Step 3 "Autostart skipped (-NoAutostart)."
} else {
    Step 3 "Enabling autostart for all users..."
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' `
        -Name 'IBS Mem Cleaner' -PropertyType String `
        -Value "`"$InstallDir\ibsmemcleaner.exe`"" -Force | Out-Null
}

# ---- 4. grant the cleaning privileges -------------------------------------
Step 4 "Granting no-UAC cleaning privileges to $Grantee..."

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

Write-Host ""
Write-Host "SUCCESS - IBS Mem Cleaner deployed." -ForegroundColor Green
Write-Host "Have the user(s) log off/on (or reboot) ONCE, then Clean memory runs with no UAC." -ForegroundColor Yellow

# clean exit code for RMM tools (Action1, etc.). Any failure above throws under
# $ErrorActionPreference='Stop' and exits non-zero, which the RMM reports as failed.
exit 0
