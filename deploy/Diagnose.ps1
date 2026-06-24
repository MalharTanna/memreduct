# ============================================================================
# IBS Mem Cleaner - diagnose "no clean-log.csv". Run via Action1 (as SYSTEM).
# Reports what exists, the task's last result, then runs the clean/log wrapper
# inline so you can see any error and whether the CSV gets created.
# ============================================================================
$ErrorActionPreference = 'Continue'

$dir    = 'C:\Program Files\IBS Mem Cleaner'
$exe    = Join-Path $dir 'ibsmemcleaner.exe'
$wrap   = Join-Path $dir 'clean-and-log.ps1'
$logDir = 'C:\ProgramData\IBS Mem Cleaner'
$log    = Join-Path $logDir 'clean-log.csv'
$task   = 'IBS Mem Cleaner AutoClean'

Write-Output "HOST            : $env:COMPUTERNAME"
Write-Output "running as      : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Output "exe exists      : $(Test-Path $exe)"
Write-Output "wrapper exists  : $(Test-Path $wrap)"
Write-Output "logDir exists   : $(Test-Path $logDir)"
Write-Output "log exists      : $(Test-Path $log)"

$t = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
Write-Output "task exists     : $([bool]$t)"
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName $task
    Write-Output ("task lastRun    : {0}" -f $info.LastRunTime)
    Write-Output ("task lastResult : 0x{0:X8}" -f ($info.LastTaskResult))
}

Write-Output "--- running the clean/log wrapper inline ---"
if (Test-Path $wrap) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrap 2>&1 | ForEach-Object { Write-Output "  $_" }
    Write-Output "wrapper exit    : $LASTEXITCODE"
} else {
    Write-Output "WRAPPER MISSING -> deployment did not complete (likely aborted earlier)."
    Write-Output "   Re-run the full Install-IbsMemCleaner.ps1 - it recreates the wrapper + task."
}

Write-Output "log exists now  : $(Test-Path $log)"
if (Test-Path $log) {
    Write-Output "--- last rows of clean-log.csv ---"
    Get-Content $log -Tail 5 | ForEach-Object { Write-Output "  $_" }
}
