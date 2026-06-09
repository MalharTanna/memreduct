@echo off
:: ===========================================================================
:: IBS Mem Cleaner - FLEET deployment. Run as SYSTEM / Administrator on each PC
:: (push via Seqrite software deployment or a GPO computer startup script).
::
:: Keep these four files together in the same folder:
::   deploy-fleet.cmd   ibsmemcleaner.exe   ibs-codesign.cer   grant-clean-privileges.ps1
::
:: It performs, machine-wide:
::   1. trust the code-signing cert  (no SmartScreen / Seqrite-publisher trust)
::   2. install ibsmemcleaner.exe to %ProgramFiles%\IBS Mem Cleaner
::   3. autostart it for every user at logon (HKLM Run)
::   4. grant the no-UAC memory-cleaning privileges to standard users
::
:: Users must log off/on (or reboot) ONCE afterwards for step 4 to take effect.
::
:: Optional arg: an account/SID to receive the cleaning rights.
::   default = *S-1-5-32-545 (BUILTIN\Users = all standard users on the PC).
::   e.g.  deploy-fleet.cmd "CONTOSO\jdoe"   or   deploy-fleet.cmd "S-1-5-21-..."
:: ===========================================================================
setlocal
set "HERE=%~dp0"
set "APPDIR=%ProgramFiles%\IBS Mem Cleaner"
set "GRANTEE=%~1"
if "%GRANTEE%"=="" set "GRANTEE=S-1-5-32-545"

net session >nul 2>&1 || (echo [ERROR] Must run elevated (Administrator/SYSTEM). & exit /b 1)

for %%F in (ibsmemcleaner.exe ibs-codesign.cer grant-clean-privileges.ps1) do (
    if not exist "%HERE%%%F" ( echo [ERROR] Missing "%%F" next to this script. & exit /b 1 )
)

echo [1/4] Trusting code-signing certificate...
certutil -addstore -f "TrustedPublisher" "%HERE%ibs-codesign.cer" >nul || goto err
certutil -addstore -f "Root"            "%HERE%ibs-codesign.cer" >nul || goto err

echo [2/4] Installing app to "%APPDIR%"...
if not exist "%APPDIR%" mkdir "%APPDIR%"
copy /y "%HERE%ibsmemcleaner.exe" "%APPDIR%\ibsmemcleaner.exe" >nul || goto err

echo [3/4] Enabling autostart for all users...
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "IBS Mem Cleaner" /t REG_SZ /d "\"%APPDIR%\ibsmemcleaner.exe\"" /f >nul || goto err

echo [4/4] Granting no-UAC cleaning privileges to %GRANTEE%...
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%grant-clean-privileges.ps1" -Account "%GRANTEE%" || goto err

echo.
echo SUCCESS. Have users log off/on (or reboot) once; then Clean memory runs with no UAC.
exit /b 0

:err
echo.
echo [ERROR] A deployment step failed (exit %errorlevel%).
exit /b 1
