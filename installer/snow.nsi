Unicode true
!ifndef APPSEP
 !define APPSEP "/"
!endif
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
Name "Snow"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Snow"
InstallDirRegKey HKCU "Software\SnowDesktop" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Snow 0.3.9-win.6"
!define MUI_ICON "${APPDIR}${APPSEP}assets${APPSEP}snow.ico"
!define MUI_UNICON "${APPDIR}${APPSEP}assets${APPSEP}snow.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "$(WelcomeTitle)"
!define MUI_WELCOMEPAGE_TEXT "$(WelcomeBody)"
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\SnowDesktop"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Snow.exe"
!define MUI_FINISHPAGE_RUN_PARAMETERS "--settings"
!define MUI_FINISHPAGE_RUN_TEXT "$(RunSnow)"
!insertmacro MUI_PAGE_FINISH
!define MUI_UNCONFIRMPAGE_TEXT_TOP "$(UninstallBody)"
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Russian"
LangString WelcomeTitle ${LANG_ENGLISH} "Snow for Windows"
LangString WelcomeTitle ${LANG_RUSSIAN} "Снег для Windows"
LangString WelcomeBody ${LANG_ENGLISH} "Snowfall, snowmen, garlands and winter trees on your desktop.$\r$\n$\r$\nThis installer runs for the current user and works offline.$\r$\n$\r$\nQuit Snow from the notification area before upgrading."
LangString WelcomeBody ${LANG_RUSSIAN} "Снег, снеговики, гирлянды и ёлочки на рабочем столе.$\r$\n$\r$\nУстановка для текущего пользователя работает без интернета.$\r$\n$\r$\nПеред обновлением завершите Снег через значок в области уведомлений."
LangString RunSnow ${LANG_ENGLISH} "Run Snow"
LangString RunSnow ${LANG_RUSSIAN} "Запустить Снег"
LangString UninstallBody ${LANG_ENGLISH} "Snow and its shortcuts will be removed. Your settings will be kept."
LangString UninstallBody ${LANG_RUSSIAN} "Приложение и ярлыки будут удалены. Ваши настройки сохранятся."
LangString NeedWindows ${LANG_ENGLISH} "Snow requires 64-bit Windows 10 or 11."
LangString NeedWindows ${LANG_RUSSIAN} "Нужна 64-разрядная Windows 10 или 11."
LangString QuitFirst ${LANG_ENGLISH} "Quit Snow from the notification area before continuing."
LangString QuitFirst ${LANG_RUSSIAN} "Завершите Снег через значок в области уведомлений и запустите установщик снова."
VIProductVersion "0.3.9.6"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "Snow for Windows"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "Snow Setup"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "0.3.9.6"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "Snow Desktop"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "ProductName" "Снег для Windows"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileDescription" "Установщик Снега"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "FileVersion" "0.3.9.6"
VIAddVersionKey /LANG=${LANG_RUSSIAN} "LegalCopyright" "Snow Desktop"

Function .onInit
 SetRegView 64
 !insertmacro MUI_LANGDLL_DISPLAY
 ${IfNot} ${RunningX64}
  MessageBox MB_ICONSTOP "$(NeedWindows)"
  Abort
 ${EndIf}
 ${IfNot} ${AtLeastWin10}
  MessageBox MB_ICONSTOP "$(NeedWindows)"
  Abort
 ${EndIf}
 FindWindow $0 "SnowDesktop.Tray"
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "$(QuitFirst)"
  Abort
 ${EndIf}
FunctionEnd

Section "Снег" SEC_SNOW
 SetShellVarContext current
 SetOutPath "$INSTDIR"
 File "${APPDIR}${APPSEP}Snow.exe"
 File "${APPDIR}${APPSEP}INSTALL.txt"
 File "${APPDIR}${APPSEP}THIRD_PARTY.md"
 SetOutPath "$INSTDIR\assets"
 File "${APPDIR}${APPSEP}assets${APPSEP}snow.ico"
 File "${APPDIR}${APPSEP}assets${APPSEP}cabin.png"
 File "${APPDIR}${APPSEP}assets${APPSEP}porch.png"
 File "${APPDIR}${APPSEP}assets${APPSEP}tree-vector.svg"
 SetOutPath "$INSTDIR\licenses"
 File /nonfatal "${APPDIR}${APPSEP}licenses${APPSEP}*"
 SetOutPath "$INSTDIR"
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 CreateDirectory "$SMPROGRAMS\Снег"
 CreateShortcut "$SMPROGRAMS\Снег\Снег.lnk" "$INSTDIR\Snow.exe" "--settings" "$INSTDIR\Snow.exe" 0
 CreateShortcut "$SMPROGRAMS\Снег\Удалить Снег.lnk" "$INSTDIR\Uninstall.exe"
 WriteRegStr HKCU "Software\SnowDesktop" "InstallDir" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayName" "Снег"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayVersion" "0.3.9.6"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "DisplayIcon" "$INSTDIR\Snow.exe"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "InstallLocation" "$INSTDIR"
 WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "NoModify" 1
 WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop" "NoRepair" 1
SectionEnd

Function un.onInit
 SetRegView 64
 !insertmacro MUI_UNGETLANGUAGE
 FindWindow $0 "SnowDesktop.Tray"
 ${If} $0 != 0
  MessageBox MB_ICONSTOP "$(QuitFirst)"
  Abort
 ${EndIf}
FunctionEnd
Section "Uninstall"
 SetShellVarContext current
 ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SnowDesktop"
 StrCmp $0 '$\"$INSTDIR\Snow.exe$\"' 0 +2
 DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SnowDesktop"
 Delete "$SMPROGRAMS\Снег\Снег.lnk"
 Delete "$SMPROGRAMS\Снег\Удалить Снег.lnk"
 RMDir "$SMPROGRAMS\Снег"
 Delete "$INSTDIR\Snow.exe"
 Delete "$INSTDIR\INSTALL.txt"
 Delete "$INSTDIR\THIRD_PARTY.md"
 Delete "$INSTDIR\assets\snow.ico"
 Delete "$INSTDIR\assets\cabin.png"
 Delete "$INSTDIR\assets\porch.png"
 Delete "$INSTDIR\assets\tree-vector.svg"
 RMDir "$INSTDIR\assets"
 Delete "$INSTDIR\licenses\LLVM.txt"
 Delete "$INSTDIR\licenses\Zig.txt"
 Delete "$INSTDIR\licenses\NSIS.txt"
 RMDir "$INSTDIR\licenses"
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SnowDesktop"
 DeleteRegKey HKCU "Software\SnowDesktop"
SectionEnd
