<#
  Grants the two privileges IBS Mem Cleaner needs to clean memory without UAC:
    - SeProfileSingleProcessPrivilege  ("Profile single process")
    - SeIncreaseQuotaPrivilege         ("Adjust memory quotas for a process")

  Run ELEVATED (the grant-privileges.cmd launcher does this for you). After it
  succeeds, LOG OFF AND BACK ON so the account's logon token picks up the rights.

  Usage:  powershell -ExecutionPolicy Bypass -File grant-clean-privileges.ps1 -Account "DOMAIN\user"
          (defaults to the current user if -Account is omitted)
#>
param(
    [string]$Account = "$env:USERDOMAIN\$env:USERNAME"
)

$ErrorActionPreference = 'Stop'

$rights = @('SeProfileSingleProcessPrivilege', 'SeIncreaseQuotaPrivilege')

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
    [DllImport("advapi32.dll")]
    public static extern uint LsaClose(IntPtr PolicyHandle);
    [DllImport("advapi32.dll")]
    public static extern int LsaNtStatusToWinError(uint Status);

    public static LSA_UNICODE_STRING Str(string s) {
        LSA_UNICODE_STRING u = new LSA_UNICODE_STRING();
        u.Buffer = Marshal.StringToHGlobalUni(s);
        u.Length = (ushort)(s.Length * 2);
        u.MaximumLength = (ushort)(s.Length * 2 + 2);
        return u;
    }
}
'@

# resolve account -> SID bytes
$sid = (New-Object System.Security.Principal.NTAccount($Account)).Translate([System.Security.Principal.SecurityIdentifier])
$sidBytes = New-Object byte[] $sid.BinaryLength
$sid.GetBinaryForm($sidBytes, 0)
Write-Host "Account : $Account  ($($sid.Value))"

# open LSA policy (POLICY_ALL_ACCESS)
$oa  = New-Object LsaHelper+LSA_OBJECT_ATTRIBUTES
$sys = New-Object LsaHelper+LSA_UNICODE_STRING
$h   = [IntPtr]::Zero
$st  = [LsaHelper]::LsaOpenPolicy([ref]$sys, [ref]$oa, 0x000F0FFF, [ref]$h)
if ($st -ne 0) { throw "LsaOpenPolicy failed (WinError $([LsaHelper]::LsaNtStatusToWinError($st)))" }

try {
    $lsaRights = [LsaHelper+LSA_UNICODE_STRING[]]($rights | ForEach-Object { [LsaHelper]::Str($_) })
    $st = [LsaHelper]::LsaAddAccountRights($h, $sidBytes, $lsaRights, $rights.Count)
    if ($st -ne 0) { throw "LsaAddAccountRights failed (WinError $([LsaHelper]::LsaNtStatusToWinError($st)))" }
}
finally {
    [LsaHelper]::LsaClose($h) | Out-Null
}

Write-Host ""
Write-Host "GRANTED: $($rights -join ', ')" -ForegroundColor Green
Write-Host "Now LOG OFF and back on, then click Clean memory - it should no longer prompt for UAC." -ForegroundColor Yellow
