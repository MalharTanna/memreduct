@echo off
:: Build the per-user, NO-UAC Mem Reduct installer.
:: Requires NSIS (makensis) on PATH and an already-built memreduct.exe.
setlocal
cd /d "%~dp0"

:: ---- EDIT IF NEEDED -------------------------------------------------------
set "VER=3.5.3"
set "FILES=..\bin"
::            ^-- folder that holds the built memreduct.exe (+ .lng, *.txt)
:: ---------------------------------------------------------------------------

where makensis >nul 2>nul || (
    echo [ERROR] makensis not found on PATH. Install NSIS ^(https://nsis.sourceforge.io^).
    exit /b 1
)

if not exist "%FILES%\memreduct.exe" (
    echo [ERROR] memreduct.exe not found in "%FILES%".
    echo         Build the app first, or point FILES at the output folder.
    exit /b 1
)

makensis /DAPP_VERSION=%VER% /DAPP_FILES_DIR="%FILES%" setup_user.nsi
if errorlevel 1 (
    echo [ERROR] makensis failed.
    exit /b 1
)

echo.
echo Done -> memreduct-%VER%-setup-user.exe
echo This installer runs with NO UAC prompt for a standard user.
endlocal
