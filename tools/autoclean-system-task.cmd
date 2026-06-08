@echo off
:: ===========================================================================
:: IBS Mem Cleaner - Path B fallback: background auto-clean as SYSTEM (no UAC)
:: ===========================================================================
:: Registers a Scheduled Task that runs "ibsmemcleaner.exe -clean" as the SYSTEM
:: account on a timer. SYSTEM already holds every privilege, so the clean runs
:: with NO UAC prompt regardless of who is logged in. The standard user's GUI
:: keeps running separately for monitoring.
::
:: This is a FALLBACK to the Path A code patch (see PATCH-NO-UAC.md). With Path A
:: working you do not need this; it is useful before the privilege grant takes
:: effect, or on machines where you would rather not touch User Rights Assignment.
::
:: Run this script ELEVATED (right-click -> Run as administrator) ONCE.
:: ---------------------------------------------------------------------------
:: NOTE: a SYSTEM run uses SYSTEM's own IBS Mem Cleaner config (not the user's), and
:: the -clean path tries to show a result message. In session 0 that message has
:: no desktop and returns immediately, so the task does not hang -- but you get
:: no visible confirmation. Use Task Scheduler -> History, or enable file logging
:: in SYSTEM's config, to confirm runs.
:: ===========================================================================

setlocal

:: ---- EDIT THIS: full path to your patched ibsmemcleaner.exe --------------------
set "EXE=C:\Program Files\IBS Mem Cleaner\ibsmemcleaner.exe"

:: ---- clean interval in minutes --------------------------------------------
set "EVERY=30"

:: ---- task name ------------------------------------------------------------
set "TASK=IBS Mem Cleaner AutoClean (SYSTEM)"
:: ---------------------------------------------------------------------------

if not exist "%EXE%" (
    echo [ERROR] ibsmemcleaner.exe not found at:
    echo         %EXE%
    echo Edit the EXE path at the top of this script.
    exit /b 1
)

echo Registering scheduled task "%TASK%"
echo   exe      : %EXE%
echo   command  : -clean   ^(default regions; use -clean:full for all^)
echo   interval : every %EVERY% minute^(s^)
echo   run as   : SYSTEM, highest privileges, no UAC
echo.

schtasks /Create ^
    /TN "%TASK%" ^
    /TR "\"%EXE%\" -clean" ^
    /SC MINUTE /MO %EVERY% ^
    /RU "SYSTEM" /RL HIGHEST ^
    /F

if errorlevel 1 (
    echo.
    echo [ERROR] Task creation failed. Make sure this prompt is elevated.
    exit /b 1
)

echo.
echo Done. Manage it under Task Scheduler, or:
echo   run now : schtasks /Run    /TN "%TASK%"
echo   remove  : schtasks /Delete /TN "%TASK%" /F
echo.
echo To clean ALL regions instead of the default set, re-run with -clean:full
echo by editing the /TR line above.

endlocal
