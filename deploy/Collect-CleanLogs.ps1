# ============================================================================
# IBS Mem Cleaner - collect/summarize the cleaning log. RMM-safe (no param()).
# Run via Action1 (per endpoint, as SYSTEM). For each PC it prints a one-line
# summary + the full CSV to the script output, which Action1 aggregates centrally.
# Optionally also copies the CSV to a file share.
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'

# ===== optional: copy each PC's log to a share ==============================
$Share = ''   # e.g. '\\server\IBSLogs'. Leave '' to only print to Action1 output.
#              (Share copy needs the machine account to have write access - works
#               on AD domains; for a no-domain fleet use the printed output instead.)
# ============================================================================

$log = 'C:\ProgramData\IBS Mem Cleaner\clean-log.csv'

if (-not (Test-Path $log)) {
    Write-Output "[$env:COMPUTERNAME] NO clean-log.csv found (app not deployed yet, or no clean has run)"
    exit 0
}

$rows = @(Import-Csv $log)
$count = $rows.Count
$totalFreed = if ($count) { [math]::Round((($rows | Measure-Object -Property FreedMB -Sum).Sum), 1) } else { 0 }
$first = if ($count) { $rows[0].Timestamp } else { '-' }
$last  = if ($count) { $rows[$count - 1].Timestamp } else { '-' }

Write-Output "[$env:COMPUTERNAME] cleans=$count  totalFreedMB=$totalFreed  from=$first  to=$last"

if ($Share) {
    try {
        New-Item -ItemType Directory -Force -Path $Share | Out-Null
        Copy-Item $log (Join-Path $Share "$env:COMPUTERNAME-clean-log.csv") -Force
        Write-Output "[$env:COMPUTERNAME] copied log to $Share"
    } catch {
        Write-Output "[$env:COMPUTERNAME] share copy FAILED: $($_.Exception.Message)"
    }
} else {
    Write-Output "----- full log ($env:COMPUTERNAME) -----"
    Get-Content $log | Write-Output
}

exit 0
