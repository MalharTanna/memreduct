@echo off
:: ===========================================================================
:: One-click: grant the current user the two privileges IBS Mem Cleaner needs
:: to clean memory WITHOUT UAC. Self-elevates (you approve ONE UAC prompt here),
:: then grants the rights to the account you are currently logged in as.
::
:: AFTER it finishes: LOG OFF and back on, then Clean memory won't prompt.
:: Keep grant-clean-privileges.ps1 next to this file.
:: ===========================================================================
setlocal

:: Capture the *current* (standard) user BEFORE elevating. After UAC elevation
:: the process runs as the admin account, so we must pass this through.
set "TARGET=%USERDOMAIN%\%USERNAME%"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights to grant privileges to %TARGET% ...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%TARGET%' -Verb RunAs"
    exit /b
)

:: --- elevated from here ---
set "ACCOUNT=%~1"
if "%ACCOUNT%"=="" set "ACCOUNT=%USERDOMAIN%\%USERNAME%"

echo Granting memory-cleaning privileges to: %ACCOUNT%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0grant-clean-privileges.ps1" -Account "%ACCOUNT%"

echo.
pause
