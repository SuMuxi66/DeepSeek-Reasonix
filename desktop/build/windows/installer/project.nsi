Unicode true

####
## Reasonix per-user NSIS installer.
##
## This file is COMMITTED and customized (Wails leaves an existing project.nsi
## untouched and only regenerates wails_tools.nsh). The customizations vs.
## Wails' default template:
##
##   1. REQUEST_EXECUTION_LEVEL "user" + InstallDir under $LOCALAPPDATA - install
##      without administrator rights. This is what lets the auto-updater re-run a
##      freshly downloaded installer silently (`/S`) with no UAC prompt.
##   2. Uninstall registry under HKCU (not HKLM). Wails' wails.writeUninstaller /
##      wails.deleteUninstaller macros hard-code HKLM, which a non-admin install
##      cannot write - so we inline HKCU versions below instead.
##   3. InstallDir is remembered across updates via InstallDirRegKey +
##      InstallLocation (HKCU\...\Uninstall\InstallLocation). When upgrading from
##      a build that did not write InstallLocation yet, .onInit falls back to the
##      old DisplayIcon path before using the default. Without this, every release
##      forces the user back to %LOCALAPPDATA%\Programs\Reasonix even if they had
##      moved the install to a different drive (e.g. D:\Tools\Reasonix); the silent
##      auto-updater would re-run with /S into the wrong dir, leaving the old
##      install orphaned.
##   4. Chinese (Simplified) localization for installer UI.
##   5. Custom options page: desktop shortcut, start menu shortcut, run after install.
##   6. Pre-install process detection via nsExec (Wails-bundled plugin).
##
## Everything else mirrors Wails' generated default. Defines below override the
## ProjectInfo values that wails_tools.nsh would otherwise populate.
####

## Install per-user (no admin). Must be defined BEFORE including wails_tools.nsh,
## which only sets the "admin" default when REQUEST_EXECUTION_LEVEL is undefined.
!define REQUEST_EXECUTION_LEVEL "user"

####
## Include the wails tools (auto-generated; provides INFO_* defines and the
## wails.* macros used below).
####
!include "wails_tools.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"

# The version information for this two must consist of 4 parts
VIProductVersion "${INFO_PRODUCTVERSION}.0"
VIFileVersion    "${INFO_PRODUCTVERSION}.0"

VIAddVersionKey "CompanyName"     "${INFO_COMPANYNAME}"
VIAddVersionKey "FileDescription" "${INFO_PRODUCTNAME} Installer"
VIAddVersionKey "ProductVersion"  "${INFO_PRODUCTVERSION}"
VIAddVersionKey "FileVersion"     "${INFO_PRODUCTVERSION}"
VIAddVersionKey "LegalCopyright"  "${INFO_COPYRIGHT}"
VIAddVersionKey "ProductName"     "${INFO_PRODUCTNAME}"

# Enable HiDPI support. https://nsis.sourceforge.io/Reference/ManifestDPIAware
ManifestDPIAware true

!include "MUI.nsh"

!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "resources\leftimage.bmp" # 164x314 branding panel
!define MUI_INSTFILES_BITMAP "resources\banner_instfiles.bmp" # 493x58 progress page banner
!define MUI_FINISHPAGE_NOAUTOCLOSE # Wait on the INSTFILES page so the user can take a look into the details of the installation steps
!define MUI_ABORTWARNING # This will warn the user if they exit from the installer.
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXECUTABLE}" # Option to run Reasonix after install
!define MUI_FINISHPAGE_RUN_TEXT "$(MSG_OPTIONS_RUNAFTER)"

## ─── Custom Options Page Variables ────────────────────────────────────────────
Var CheckboxDesktop
Var CheckboxStartMenu
Var bCreateDesktop
Var bCreateStartMenu

!insertmacro MUI_PAGE_WELCOME # Welcome to the installer page.
!insertmacro MUI_PAGE_LICENSE "resources\eula.txt" # EULA page (matches Stitch reasonix_3 design)
Page custom fnc_Options_Show fnc_Options_Leave # Custom options page
!insertmacro MUI_PAGE_DIRECTORY # In which folder install page.
!insertmacro MUI_PAGE_INSTFILES # Installing page.
!insertmacro MUI_PAGE_FINISH # Finished installation page.

!insertmacro MUI_UNPAGE_INSTFILES # Uninstalling page

## ─── Languages (Chinese first for Chinese users, English as fallback) ────────
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

## The following two statements can be used to sign the installer and the uninstaller. The path to the binaries are provided in %1
#!uninstfinalize 'signtool --file "%1"'
#!finalize 'signtool --file "%1"'

Name "${INFO_PRODUCTNAME}"
OutFile "..\..\bin\${INFO_PROJECTNAME}-${ARCH}-installer.exe" # Name of the installer's file.
!define REASONIX_DEFAULT_INSTALLDIR "$LOCALAPPDATA\Programs\${INFO_PRODUCTNAME}"
InstallDirRegKey HKCU "${UNINST_KEY}" "InstallLocation" # Reuse the previous install path on update; .onInit falls back to the default on first install.
InstallDir "${REASONIX_DEFAULT_INSTALLDIR}" # Per-user install location (no admin rights required).
ShowInstDetails show # This will always show the installation details.

####
## Per-user uninstaller registry (HKCU). Replaces wails.writeUninstaller /
## wails.deleteUninstaller, which write HKLM and would fail without admin rights.
####
!macro reasonix.writeUninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"

    WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${INFO_COMPANYNAME}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${INFO_PRODUCTNAME}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${INFO_PRODUCTVERSION}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXECUTABLE}"
    WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    # Persist the resolved install path so a subsequent update picks it up
    # via InstallDirRegKey above. Without this, every release would force the
    # user back to %LOCALAPPDATA%\Programs\Reasonix even if they had moved
    # the install to a different drive (e.g. D:\Tools\Reasonix). The auto-
    # updater re-runs this installer with /S and trusts the persisted path,
    # so it has to be present before the silent re-install.
    WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"

    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
!macroend

!macro reasonix.deleteUninstaller
    Delete "$INSTDIR\uninstall.exe"
    DeleteRegKey HKCU "${UNINST_KEY}"
!macroend

####
## Pre-install process detection via nsExec (Wails-bundled NSIS plugin).
## Uses tasklist (Windows built-in) - no third-party NSIS plugins required.
####
Function CheckRunningProcess
    nsExec::ExecToStack 'tasklist /FI "IMAGENAME eq reasonix-desktop.exe" /NH'
    Pop $0  ; exit code: 0 = found, 1 = not found
    Pop $1  ; stdout output
    ${If} $0 == 0
        ; Process found - warn the user
        MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "$(MSG_RUNNING_PROCESS)" IDOK proceed IDCANCEL abort
        proceed:
            ; User chose to continue - proceed with install (files may be locked)
            Return
        abort:
            ; User chose to abort - quit installer
            Quit
    ${EndIf}
FunctionEnd

####
## .onInit: Architecture check + path recovery + default options + process detection.
####
Function .onInit
    !insertmacro wails.checkArchitecture

    ; ─── Initialize option defaults (for silent /S mode) ──────────────────
    ; Non-silent: user can customize on the Options page.
    ; Silent (auto-updater): create shortcuts for consistency.
    StrCpy $bCreateDesktop ${BST_CHECKED}
    StrCpy $bCreateStartMenu ${BST_CHECKED}

    ; ─── Path recovery (unchanged from original) ─────────────────────────
    ; InstallDirRegKey leaves $INSTDIR empty when the InstallLocation value is
    ; missing. Older installers still wrote DisplayIcon, so use its parent folder
    ; as a compatibility bridge before falling back to the per-user default.
    StrCmp $INSTDIR "" 0 checkRunning
    ClearErrors
    ReadRegStr $0 HKCU "${UNINST_KEY}" "DisplayIcon"
    IfErrors fallback
    StrCmp $0 "" fallback
    ${GetParent} "$0" $INSTDIR
    StrCmp $INSTDIR "" fallback checkRunning

fallback:
    StrCpy $INSTDIR "${REASONIX_DEFAULT_INSTALLDIR}"

checkRunning:
    ; Check if reasonix-desktop.exe is running (skip in silent mode for auto-updater)
    ${IfNot} ${Silent}
        Call CheckRunningProcess
    ${EndIf}
done:
FunctionEnd

####
## Custom Options Page: desktop shortcut, start menu shortcut, run after install.
####
Function fnc_Options_Show
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 20u "$(MSG_OPTIONS_TITLE)"
    Pop $0

    ${NSD_CreateCheckbox} 0 30u 100% 15u "$(MSG_OPTIONS_DESKTOP)"
    Pop $CheckboxDesktop
    ${NSD_Check} $CheckboxDesktop  ; Default checked

    ${NSD_CreateCheckbox} 0 55u 100% 15u "$(MSG_OPTIONS_STARTMENU)"
    Pop $CheckboxStartMenu
    ${NSD_Check} $CheckboxStartMenu  ; Default checked

    nsDialogs::Show
FunctionEnd

Function fnc_Options_Leave
    ${NSD_GetState} $CheckboxDesktop $bCreateDesktop
    ${NSD_GetState} $CheckboxStartMenu $bCreateStartMenu
FunctionEnd

####
## Install Section
####
Section
    !insertmacro wails.setShellContext

    !insertmacro wails.webview2runtime

    SetOutPath $INSTDIR

    !insertmacro wails.files

    ; Create shortcuts based on user options
    ${If} $bCreateStartMenu == ${BST_CHECKED}
        CreateShortcut "$SMPROGRAMS\${INFO_PRODUCTNAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}"
    ${EndIf}

    ${If} $bCreateDesktop == ${BST_CHECKED}
        CreateShortCut "$DESKTOP\${INFO_PRODUCTNAME}.lnk" "$INSTDIR\${PRODUCT_EXECUTABLE}"
    ${EndIf}

    !insertmacro wails.associateFiles
    !insertmacro wails.associateCustomProtocols

    !insertmacro reasonix.writeUninstaller
SectionEnd

####
## Uninstall Section
####
Section "uninstall"
    !insertmacro wails.setShellContext

    RMDir /r "$AppData\${PRODUCT_EXECUTABLE}" # Remove the WebView2 DataPath

    RMDir /r $INSTDIR

    Delete "$SMPROGRAMS\${INFO_PRODUCTNAME}.lnk"
    Delete "$DESKTOP\${INFO_PRODUCTNAME}.lnk"

    !insertmacro wails.unassociateFiles
    !insertmacro wails.unassociateCustomProtocols

    !insertmacro reasonix.deleteUninstaller
SectionEnd

####
## Localization strings (SimpChinese + English)
####

; ─── Chinese (Simplified) ─────────────────────────────────────────────────────
LangString MSG_RUNNING_PROCESS ${LANG_SIMPCHINESE} \
    "检测到 Reasonix 正在运行。$\r$\n$\r$\n请先关闭 Reasonix 再继续安装，否则部分文件可能无法更新。$\r$\n$\r$\n点击「确定」继续安装，点击「取消」退出安装程序。"

LangString MSG_OPTIONS_TITLE ${LANG_SIMPCHINESE} \
    "安装选项"

LangString MSG_OPTIONS_DESKTOP ${LANG_SIMPCHINESE} \
    "创建桌面快捷方式"

LangString MSG_OPTIONS_STARTMENU ${LANG_SIMPCHINESE} \
    "创建开始菜单快捷方式"

LangString MSG_OPTIONS_RUNAFTER ${LANG_SIMPCHINESE} \
    "安装完成后立即运行 Reasonix"

; ─── English ──────────────────────────────────────────────────────────────────
LangString MSG_RUNNING_PROCESS ${LANG_ENGLISH} \
    "Reasonix is currently running.$\r$\n$\r$\nPlease close Reasonix before continuing. Otherwise, some files may not be updated.$\r$\n$\r$\nClick OK to continue installation, or Cancel to exit."

LangString MSG_OPTIONS_TITLE ${LANG_ENGLISH} \
    "Installation Options"

LangString MSG_OPTIONS_DESKTOP ${LANG_ENGLISH} \
    "Create desktop shortcut"

LangString MSG_OPTIONS_STARTMENU ${LANG_ENGLISH} \
    "Create Start Menu shortcut"

LangString MSG_OPTIONS_RUNAFTER ${LANG_ENGLISH} \
    "Launch Reasonix after installation"
