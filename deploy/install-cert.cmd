@echo off
:: ===========================================================================
:: Trust the IBS Mem Cleaner code-signing certificate on this machine.
:: Run as Administrator (or push via Seqrite / GPO startup script to the fleet).
:: After this, the signed ibsmemcleaner.exe / installer launch with no
:: SmartScreen prompt and Seqrite treats them as a trusted publisher.
:: ===========================================================================
setlocal
set "CER=%~dp0ibs-codesign.cer"

if not exist "%CER%" (
    echo [ERROR] ibs-codesign.cer not found next to this script.
    exit /b 1
)

echo Adding IBS code-signing cert to Trusted Publishers (LocalMachine)...
certutil -addstore -f "TrustedPublisher" "%CER%"
if errorlevel 1 goto err

echo Adding to Trusted Root (self-signed chain)...
certutil -addstore -f "Root" "%CER%"
if errorlevel 1 goto err

echo.
echo Done. Signed IBS Mem Cleaner binaries are now trusted on this machine.
exit /b 0

:err
echo.
echo [ERROR] certutil failed. Make sure this runs elevated (as Administrator).
exit /b 1
