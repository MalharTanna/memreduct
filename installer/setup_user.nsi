; ============================================================================
; IBS Mem Cleaner - per-user, NO-UAC installer (standard-user friendly)
; ----------------------------------------------------------------------------
; Unlike the stock henrypp installer (builder/src/setup_script.nsi) this one:
;   * RequestExecutionLevel user      -> no UAC prompt at all
;   * installs to %LOCALAPPDATA%       -> writable without admin
;   * writes HKCU (not HKLM)           -> per-user uninstall entry, no admin
;   * per-user Desktop/Start shortcuts -> writable without admin
;
; Pair this with the app patch (PATCH-NO-UAC.md) so the installed standard-user
; build also CLEANS without UAC.
;
; Build (run from this folder, NSIS must be installed):
;   makensis /DAPP_VERSION=3.5.3 /DAPP_FILES_DIR=..\bin setup_user.nsi
; or just run build_installer.bat
; Produces: ibsmemcleaner-<ver>-setup-user.exe
; ============================================================================

Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

!define APP_NAME        "IBS Mem Cleaner"
!define APP_NAME_SHORT  "ibsmemcleaner"
!define APP_AUTHOR      "Henry++"
!define APP_WEBSITE     "https://github.com/henrypp"
!define UNINST_KEY      "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME_SHORT}"
!define RUN_KEY         "Software\Microsoft\Windows\CurrentVersion\Run"

!ifndef APP_VERSION
  !define APP_VERSION "3.5.3"
!endif

; folder containing the built ibsmemcleaner.exe (+ optional .lng / License.txt / ...)
!ifndef APP_FILES_DIR
  !define APP_FILES_DIR "..\bin"
!endif

Name "${APP_NAME}"
Caption "${APP_NAME} v${APP_VERSION} (per-user setup)"
OutFile "${APP_NAME_SHORT}-${APP_VERSION}-setup-user.exe"
BrandingText "(c) ${APP_AUTHOR}. All rights reversed."

; ---- the three lines that make it NO-UAC ----
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "Software\${APP_AUTHOR}\${APP_NAME_SHORT}" "InstallLocation"

ManifestDPIAware true
ManifestSupportedOS all
ShowInstDetails show

!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_NODESC
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION RunApplication

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  SetShellVarContext current   ; per-user $SMPROGRAMS / $DESKTOP / $APPDATA
FunctionEnd

Function un.onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
  SetShellVarContext current
FunctionEnd

; ----------------------------------------------------------------------------
Section "!${APP_NAME}" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"

  File "${APP_FILES_DIR}\${APP_NAME_SHORT}.exe"
  File /nonfatal "${APP_FILES_DIR}\${APP_NAME_SHORT}.exe.sig"
  File /nonfatal "${APP_FILES_DIR}\${APP_NAME_SHORT}.lng"
  File /nonfatal "${APP_FILES_DIR}\License.txt"
  File /nonfatal "${APP_FILES_DIR}\Readme.txt"
  File /nonfatal "${APP_FILES_DIR}\History.txt"

  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKCU "Software\${APP_AUTHOR}\${APP_NAME_SHORT}" "InstallLocation" "$INSTDIR"

  ; per-user Add/Remove Programs entry (HKCU -> no admin needed)
  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayName"     "${APP_NAME}"
  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\${APP_NAME_SHORT}.exe"
  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr   HKCU "${UNINST_KEY}" "Publisher"       "${APP_AUTHOR}"
  WriteRegStr   HKCU "${UNINST_KEY}" "URLInfoAbout"    "${APP_WEBSITE}"
  WriteRegStr   HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKCU "${UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_NAME_SHORT}.exe"
SectionEnd

Section "Start menu shortcuts" SecStartMenu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_NAME_SHORT}.exe"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall.lnk"   "$INSTDIR\uninstall.exe"
SectionEnd

Section /o "Run at sign-in (current user)" SecAutorun
  WriteRegStr HKCU "${RUN_KEY}" "${APP_NAME}" '"$INSTDIR\${APP_NAME_SHORT}.exe"'
SectionEnd

Function RunApplication
  ${If} ${FileExists} "$INSTDIR\${APP_NAME_SHORT}.exe"
    Exec '"$INSTDIR\${APP_NAME_SHORT}.exe"'
  ${EndIf}
FunctionEnd

; ----------------------------------------------------------------------------
Section "Uninstall"
  SetShellVarContext current

  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"

  DeleteRegValue HKCU "${RUN_KEY}" "${APP_NAME}"
  DeleteRegKey   HKCU "${UNINST_KEY}"
  DeleteRegKey   HKCU "Software\${APP_AUTHOR}\${APP_NAME_SHORT}"

  Delete "$INSTDIR\${APP_NAME_SHORT}.exe"
  Delete "$INSTDIR\${APP_NAME_SHORT}.exe.sig"
  Delete "$INSTDIR\${APP_NAME_SHORT}.lng"
  Delete "$INSTDIR\${APP_NAME_SHORT}.ini"
  Delete "$INSTDIR\${APP_NAME_SHORT}_debug.log"
  Delete "$INSTDIR\License.txt"
  Delete "$INSTDIR\Readme.txt"
  Delete "$INSTDIR\History.txt"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  ; non-portable config lives in %APPDATA%
  RMDir /r "$APPDATA\${APP_AUTHOR}\${APP_NAME}"
  RMDir "$APPDATA\${APP_AUTHOR}"
SectionEnd

; Version info
VIAddVersionKey "CompanyName"      "${APP_AUTHOR}"
VIAddVersionKey "FileDescription"  "${APP_NAME} per-user setup"
VIAddVersionKey "FileVersion"      "${APP_VERSION}"
VIAddVersionKey "LegalCopyright"   "(c) ${APP_AUTHOR}"
VIAddVersionKey "ProductName"      "${APP_NAME}"
VIAddVersionKey "ProductVersion"   "${APP_VERSION}"
VIProductVersion "${APP_VERSION}.0"
